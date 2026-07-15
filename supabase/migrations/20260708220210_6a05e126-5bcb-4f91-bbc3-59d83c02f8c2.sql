-- ── convertir_commande_en_bl : idempotent, ne re-décrémente pas, laisse statut='validee' ──
CREATE OR REPLACE FUNCTION public.convertir_commande_en_bl(
  _commande_id uuid, _nb_colis integer, _poids_total numeric DEFAULT NULL,
  _transporteur text DEFAULT NULL, _adresse_livraison text DEFAULT NULL,
  _signataire text DEFAULT NULL, _date_livraison date DEFAULT NULL,
  _decrementer_stock boolean DEFAULT true
)
RETURNS TABLE(bl_id uuid, reference text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_cmd public.commandes; v_bl_id uuid; v_bl_ref text; v_ordre_ref text;
  v_poids_par_colis numeric; v_uid uuid := auth.uid(); v_email text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  PERFORM public.assert_permission('commandes.livrer');

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd IS NULL THEN RAISE EXCEPTION 'Commande introuvable %', _commande_id; END IF;
  IF v_cmd.statut NOT IN ('validee','facturee') THEN
    RAISE EXCEPTION 'Commande % non éligible (statut=%)', v_cmd.reference, v_cmd.statut;
  END IF;

  SELECT bl.bl_id, bl.reference INTO v_bl_id, v_bl_ref
    FROM public.bons_livraison bl
   WHERE bl.commande_id = _commande_id AND bl.annule_at IS NULL
   ORDER BY bl.created_at ASC LIMIT 1;

  IF v_bl_id IS NULL THEN
    INSERT INTO public.bons_livraison(
      commande_id, client_id, date_emission, date_livraison,
      statut, transporteur, adresse_livraison, signataire, montant_total, notes, exercice_id
    ) VALUES (
      _commande_id, v_cmd.client_id, CURRENT_DATE, COALESCE(_date_livraison, CURRENT_DATE),
      'a_preparer', _transporteur, _adresse_livraison, _signataire,
      COALESCE(v_cmd.montant_total, 0),
      'BL issu de la commande ' || v_cmd.reference || ' — ' || _nb_colis || ' colis',
      v_cmd.exercice_id
    ) RETURNING bons_livraison.bl_id, bons_livraison.reference INTO v_bl_id, v_bl_ref;
  ELSE
    UPDATE public.bons_livraison
       SET statut = CASE WHEN statut = 'brouillon' THEN 'a_preparer' ELSE statut END,
           transporteur = COALESCE(_transporteur, transporteur),
           adresse_livraison = COALESCE(_adresse_livraison, adresse_livraison),
           signataire = COALESCE(_signataire, signataire),
           date_livraison = COALESCE(_date_livraison, date_livraison),
           updated_at = now()
     WHERE bons_livraison.bl_id = v_bl_id;
  END IF;

  v_ordre_ref := 'ORD-' || to_char(now(),'YYYYMMDD-HH24MISSMS');
  INSERT INTO public.ordres_colisage(reference, commande_id, nb_colis, poids_total, statut, notes)
  VALUES (v_ordre_ref, _commande_id, _nb_colis, _poids_total, 'prepare', 'Colisage pour ' || v_bl_ref)
  ON CONFLICT DO NOTHING;

  v_poids_par_colis := CASE WHEN _poids_total IS NOT NULL AND _nb_colis > 0
                            THEN ROUND(_poids_total / _nb_colis, 2) ELSE 0 END;

  IF NOT EXISTS (SELECT 1 FROM public.colis WHERE bl_id = v_bl_id) THEN
    INSERT INTO public.colis(
      reference, destinataire, contenu, poids, transporteur,
      date_envoi, statut, statut_logistique, bl_id, commande_id, numero_carton, nb_cartons
    )
    SELECT
      v_bl_ref || '-C' || lpad(i::text, 2, '0'),
      COALESCE(_signataire, v_cmd.client_nom, 'Client'),
      'Colis ' || i || '/' || _nb_colis || ' — ' || v_cmd.reference,
      v_poids_par_colis, _transporteur,
      COALESCE(_date_livraison, CURRENT_DATE),
      'a_expedier','a_expedier', v_bl_id, _commande_id, i, _nb_colis
    FROM generate_series(1, _nb_colis) AS i;
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, new_values)
  VALUES (v_uid, v_email, 'convertir_commande_en_bl', 'bons_livraison', v_bl_id::text,
    jsonb_build_object('commande_id', _commande_id, 'commande_reference', v_cmd.reference,
      'bl_id', v_bl_id, 'bl_reference', v_bl_ref, 'ordre_colisage_reference', v_ordre_ref,
      'nb_colis', _nb_colis, 'poids_total', _poids_total,
      'note', 'idempotent — stock inchangé (décrément fait par valider_commande), statut commande inchangé'));

  RETURN QUERY SELECT v_bl_id, v_bl_ref;
END $function$;

-- ── valider_commande : plus de mouvement à 0, refuse si stock insuffisant, idempotent ──
CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
RETURNS TABLE(facture_reference text, bl_reference text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  c record; f_ref text; b_ref text; l record;
  v_depot uuid; v_actuel int; v_bl_id uuid;
  v_manques text[] := ARRAY[]::text[];
BEGIN
  PERFORM public.assert_permission('commandes.valider');
  SELECT * INTO c FROM public.commandes WHERE commande_id = _commande_id;
  IF c IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF c.statut NOT IN ('en_attente_validation','brouillon') THEN
    SELECT reference INTO f_ref FROM public.factures WHERE commande_id = _commande_id ORDER BY created_at LIMIT 1;
    SELECT reference INTO b_ref FROM public.bons_livraison WHERE commande_id = _commande_id AND annule_at IS NULL ORDER BY created_at LIMIT 1;
    facture_reference := f_ref; bl_reference := b_ref; RETURN NEXT; RETURN;
  END IF;

  v_depot := public.resolve_depot_sortie(c.depot_id, 'commandes');

  FOR l IN SELECT produit_id, quantite FROM public.commande_lignes
           WHERE commande_id = _commande_id AND produit_id IS NOT NULL AND quantite > 0 LOOP
    INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES(l.produit_id, v_depot, 0) ON CONFLICT(produit_id, depot_id) DO NOTHING;
    SELECT COALESCE(quantite,0) INTO v_actuel FROM public.stocks_depots
      WHERE produit_id = l.produit_id AND depot_id = v_depot FOR UPDATE;
    IF v_actuel < l.quantite THEN
      v_manques := array_append(v_manques,
        format('%s (demandé %s, disponible %s)',
          (SELECT reference FROM public.produits WHERE produit_id = l.produit_id),
          l.quantite, v_actuel));
    END IF;
  END LOOP;

  IF array_length(v_manques,1) IS NOT NULL THEN
    RAISE EXCEPTION 'Stock insuffisant : %', array_to_string(v_manques, ', ') USING ERRCODE='P0001';
  END IF;

  FOR l IN SELECT produit_id, quantite FROM public.commande_lignes
           WHERE commande_id = _commande_id AND produit_id IS NOT NULL AND quantite > 0 LOOP
    SELECT quantite INTO v_actuel FROM public.stocks_depots
      WHERE produit_id = l.produit_id AND depot_id = v_depot FOR UPDATE;
    PERFORM public.ajuster_stock_depot(
      l.produit_id, v_depot, v_actuel - l.quantite,
      'Vente commande ' || c.reference, 'commande', _commande_id, c.reference, 'commandes', NULL
    );
  END LOOP;

  UPDATE public.commandes SET statut = 'validee', depot_id = v_depot, updated_at = now()
   WHERE commande_id = _commande_id;

  INSERT INTO public.factures(client_id, client_nom, commande_id, montant_total, montant_paye, statut, notes)
  VALUES (c.client_id, c.client_nom, _commande_id, c.montant_total, 0, 'impayee',
          'Facturation de la commande ' || c.reference)
  RETURNING reference INTO f_ref;

  INSERT INTO public.bons_livraison(commande_id, client_id, montant_total, statut, adresse_livraison)
  VALUES (_commande_id, c.client_id, c.montant_total, 'brouillon', c.adresse)
  RETURNING bl_id, reference INTO v_bl_id, b_ref;

  PERFORM public.creer_livraison_commande(_commande_id);
  UPDATE public.livraisons_commande SET statut = 'preparation', bl_id = v_bl_id
   WHERE commande_id = _commande_id;

  facture_reference := f_ref; bl_reference := b_ref; RETURN NEXT;
END $function$;

-- ── Nettoyage mouvements fantômes : marquer sans supprimer (trigger no_delete actif) ──
UPDATE public.stock_mouvements
   SET motif = '[FANTÔME AUDIT] ' || motif,
       observation = COALESCE(observation, '') ||
         ' — Mouvement à quantité 0 généré par valider_commande (bug A4 corrigé)'
 WHERE quantite = 0 AND type = 'ajustement' AND motif LIKE 'Vente commande %'
   AND motif NOT LIKE '[FANTÔME AUDIT]%';

COMMENT ON FUNCTION public.convertir_commande_en_bl(uuid,integer,numeric,text,text,text,date,boolean) IS
'Matérialise BL + ordre de colisage + cartons pour une commande validée. Idempotent : réutilise le BL créé par valider_commande. Ne re-décrémente pas le stock, ne modifie pas le statut de la commande.';

COMMENT ON FUNCTION public.valider_commande(uuid) IS
'Valide une commande : refuse si stock insuffisant, décrémente stocks_depots proprement (aucun mouvement à 0), crée facture + BL brouillon + livraison_commande en préparation. Idempotente.';