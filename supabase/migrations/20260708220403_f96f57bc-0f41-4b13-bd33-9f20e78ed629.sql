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

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd IS NULL THEN RAISE EXCEPTION 'Commande introuvable %', _commande_id; END IF;
  IF v_cmd.statut NOT IN ('validee','facturee') THEN
    RAISE EXCEPTION 'Commande % non éligible (statut=%)', v_cmd.reference, v_cmd.statut;
  END IF;

  SELECT b.bl_id, b.reference INTO v_bl_id, v_bl_ref
    FROM public.bons_livraison b
   WHERE b.commande_id = _commande_id AND b.annule_at IS NULL
   ORDER BY b.created_at ASC LIMIT 1;

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
    UPDATE public.bons_livraison b
       SET statut = CASE WHEN b.statut = 'brouillon' THEN 'a_preparer' ELSE b.statut END,
           transporteur = COALESCE(_transporteur, b.transporteur),
           adresse_livraison = COALESCE(_adresse_livraison, b.adresse_livraison),
           signataire = COALESCE(_signataire, b.signataire),
           date_livraison = COALESCE(_date_livraison, b.date_livraison),
           updated_at = now()
     WHERE b.bl_id = v_bl_id;
  END IF;

  v_ordre_ref := 'ORD-' || to_char(now(),'YYYYMMDD-HH24MISSMS');
  INSERT INTO public.ordres_colisage(reference, commande_id, nb_colis, poids_total, statut, notes)
  VALUES (v_ordre_ref, _commande_id, _nb_colis, _poids_total, 'prepare', 'Colisage pour ' || v_bl_ref)
  ON CONFLICT DO NOTHING;

  v_poids_par_colis := CASE WHEN _poids_total IS NOT NULL AND _nb_colis > 0
                            THEN ROUND(_poids_total / _nb_colis, 2) ELSE 0 END;

  IF NOT EXISTS (SELECT 1 FROM public.colis c WHERE c.bl_id = v_bl_id) THEN
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
      'note', 'idempotent — stock inchangé, statut commande inchangé'));

  RETURN QUERY SELECT v_bl_id, v_bl_ref;
END $function$;