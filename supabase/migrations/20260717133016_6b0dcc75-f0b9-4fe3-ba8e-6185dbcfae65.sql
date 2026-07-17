
-- 1) modifier_commande : autoriser aussi 'en_attente_validation'
CREATE OR REPLACE FUNCTION public.modifier_commande(_commande_id uuid, _payload jsonb)
RETURNS SETOF public.commandes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE
  v_statut text;
  v_ligne jsonb;
  v_tva numeric; v_remise_g numeric;
  v_total_ht_brut numeric := 0; v_total_remises numeric := 0;
  v_total_ht_net numeric; v_remise_g_mnt numeric; v_tva_mnt numeric; v_ttc numeric;
  v_nb int := 0; v_qte int := 0;
  v_qte_l numeric; v_pu numeric; v_rpct numeric; v_rmnt numeric; v_tot numeric;
BEGIN
  PERFORM public.assert_permission('commandes.modifier');

  SELECT statut INTO v_statut FROM public.commandes WHERE commande_id = _commande_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_statut NOT IN ('brouillon','soumise','en_attente_validation') THEN
    RAISE EXCEPTION 'Commande non modifiable (statut=%)', v_statut;
  END IF;

  UPDATE public.commandes SET
    client_id        = COALESCE(NULLIF(_payload->>'client_id','')::uuid, client_id),
    client_nom       = COALESCE(_payload->>'client_nom', client_nom),
    etablissement    = COALESCE(_payload->>'etablissement', etablissement),
    representant_nom = COALESCE(_payload->>'representant_nom', representant_nom),
    telephone        = COALESCE(_payload->>'telephone', telephone),
    ville            = COALESCE(_payload->>'ville', ville),
    adresse          = COALESCE(_payload->>'adresse', adresse),
    observations     = COALESCE(_payload->>'observations', observations),
    depot_id         = COALESCE(NULLIF(_payload->>'depot_id','')::uuid, depot_id)
  WHERE commande_id = _commande_id;

  IF _payload ? 'lignes' THEN
    DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;

    SELECT taux_tva, remise_globale_pct INTO v_tva, v_remise_g
    FROM public.commandes WHERE commande_id = _commande_id;
    v_tva := COALESCE((_payload->>'taux_tva')::numeric, v_tva);
    v_remise_g := COALESCE((_payload->>'remise_globale_pct')::numeric, v_remise_g);

    FOR v_ligne IN SELECT * FROM jsonb_array_elements(_payload->'lignes') LOOP
      v_qte_l := COALESCE((v_ligne->>'quantite')::numeric, 0);
      v_pu    := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
      v_rpct  := COALESCE((v_ligne->>'remise_pct')::numeric, 0);
      v_rmnt  := ROUND(v_qte_l * v_pu * v_rpct / 100, 2);
      v_tot   := ROUND(v_qte_l * v_pu - v_rmnt, 2);
      INSERT INTO public.commande_lignes(
        commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire,
        remise_pct, montant_remise, total_ligne, total_ht_ligne
      ) VALUES (
        _commande_id, NULLIF(v_ligne->>'produit_id','')::uuid, v_ligne->>'reference_produit',
        COALESCE(v_ligne->>'designation',''), v_qte_l::int, v_pu, v_rpct, v_rmnt, v_tot, v_tot
      );
      v_total_ht_brut := v_total_ht_brut + v_qte_l * v_pu;
      v_total_remises := v_total_remises + v_rmnt;
      v_nb := v_nb + 1;
      v_qte := v_qte + v_qte_l::int;
    END LOOP;

    v_total_ht_net := v_total_ht_brut - v_total_remises;
    v_remise_g_mnt := ROUND(v_total_ht_net * v_remise_g / 100, 2);
    v_total_ht_net := v_total_ht_net - v_remise_g_mnt;
    v_tva_mnt := ROUND(v_total_ht_net * v_tva / 100, 2);
    v_ttc := v_total_ht_net + v_tva_mnt;

    UPDATE public.commandes SET
      taux_tva = v_tva, remise_globale_pct = v_remise_g,
      nb_produits = v_nb, total_quantite = v_qte,
      total_ht_brut = v_total_ht_brut, total_remises_lignes = v_total_remises,
      total_ht_net = v_total_ht_net, remise_globale_montant = v_remise_g_mnt,
      montant_tva = v_tva_mnt, montant_ttc = v_ttc,
      net_a_payer = v_ttc, montant_total = v_ttc
    WHERE commande_id = _commande_id;
  END IF;

  RETURN QUERY SELECT * FROM public.commandes WHERE commande_id = _commande_id;
END; $function$;

-- 2) convertir_proforma_en_commande : aligner sur le workflow creer_commande
--    Proforma déjà existante -> pas de doublon. Génère facture+BL si perm 'commandes.valider'.
CREATE OR REPLACE FUNCTION public.convertir_proforma_en_commande(_proforma_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('CMD', 'public.commandes', 'reference');
  v_p public.proformas;
  v_ex uuid;
  v_uid uuid := auth.uid();
  v_can_valider boolean;
  v_statut text;
  v_fac_ref text;
  v_bl_ref text;
  v_ttc numeric;
BEGIN
  PERFORM public.assert_permission('proformas.convertir_en_commande');

  SELECT * INTO v_p FROM public.proformas WHERE proforma_id = _proforma_id;
  IF v_p.proforma_id IS NULL THEN RAISE EXCEPTION 'Proforma introuvable'; END IF;

  v_ex := public._resolve_exercice_id(current_date);
  IF v_ex IS NULL THEN
    SELECT exercice_id INTO v_ex FROM public.exercices_comptables WHERE is_actif
    ORDER BY date_debut DESC LIMIT 1;
  END IF;

  v_can_valider := (v_uid IS NOT NULL AND public.has_permission_v2(v_uid, 'commandes.valider'));
  v_statut := CASE WHEN v_can_valider THEN 'validee' ELSE 'en_attente_validation' END;
  v_ttc := COALESCE(v_p.montant_total, 0);

  INSERT INTO public.commandes(
    reference, client_id, client_nom, statut,
    montant_total, montant_ttc, net_a_payer, created_by, exercice_id
  ) VALUES (
    v_ref, v_p.client_id, v_p.client_nom, v_statut,
    v_ttc, v_ttc, v_ttc, v_uid, v_ex
  ) RETURNING commande_id INTO v_id;

  INSERT INTO public.commande_lignes(
    commande_id, produit_id, reference_produit, designation, quantite,
    prix_unitaire, total_ligne, total_ht_ligne
  )
  SELECT v_id, produit_id, reference_produit, COALESCE(designation,''),
         COALESCE(quantite,0)::int, COALESCE(prix_unitaire,0),
         COALESCE(total_ligne,0), COALESCE(total_ligne,0)
  FROM public.proforma_lignes WHERE proforma_id = _proforma_id;

  UPDATE public.proformas
     SET statut = 'convertie', commande_id = v_id
   WHERE proforma_id = _proforma_id;

  IF v_can_valider THEN
    v_fac_ref := public._next_ref('FAC', 'public.factures', 'reference');
    v_bl_ref  := public._next_ref('BL',  'public.bons_livraison', 'reference');

    INSERT INTO public.factures(
      reference, client_id, client_nom, commande_id, exercice_id,
      date_facture, date_echeance, montant_total, statut
    ) VALUES (
      v_fac_ref, v_p.client_id, v_p.client_nom, v_id, v_ex,
      current_date, current_date + 30, v_ttc, 'impayee'
    );

    INSERT INTO public.bons_livraison(
      reference, commande_id, client_id, client_nom, date_emission, statut, exercice_id
    ) VALUES (
      v_bl_ref, v_id, v_p.client_id, v_p.client_nom, current_date, 'a_preparer', v_ex
    );
  END IF;

  RETURN v_id;
END; $function$;

-- 3) Trigger paiements : étendre à UPDATE OF statut pour bloquer un contournement
--    (finance sans 'paiements.valider' insère en_attente puis update valide hors valider_paiement)
CREATE OR REPLACE FUNCTION public.paiements_enforce_validation()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  -- Seul un utilisateur avec 'paiements.valider' peut créer/mettre à jour un paiement en statut 'valide'
  IF NEW.statut = 'valide' THEN
    IF TG_OP = 'UPDATE' AND OLD.statut = 'valide' THEN
      -- pas de changement de statut -> laisser passer
      RETURN NEW;
    END IF;
    IF v_uid IS NULL OR NOT public.has_permission_v2(v_uid, 'paiements.valider') THEN
      -- Forcer en_attente_validation si pas la permission
      NEW.statut := 'en_attente_validation';
    END IF;
  END IF;
  RETURN NEW;
END; $function$;

DROP TRIGGER IF EXISTS trg_paiements_enforce_validation ON public.paiements;
CREATE TRIGGER trg_paiements_enforce_validation
BEFORE INSERT OR UPDATE OF statut ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.paiements_enforce_validation();
