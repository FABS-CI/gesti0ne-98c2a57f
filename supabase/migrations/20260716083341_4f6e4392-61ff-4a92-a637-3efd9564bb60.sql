
-- =====================================================================
-- MODULE VENTES — Reconstruction best-effort
-- Colonnes manquantes + RPC : proforma → commande → BL → facture → paiement
-- =====================================================================

-- ---------- Colonnes manquantes ----------
ALTER TABLE public.paiements
  ADD COLUMN IF NOT EXISTS exercice_id uuid,
  ADD COLUMN IF NOT EXISTS valide_par uuid,
  ADD COLUMN IF NOT EXISTS valide_le timestamptz,
  ADD COLUMN IF NOT EXISTS rejete_par uuid,
  ADD COLUMN IF NOT EXISTS rejete_le timestamptz,
  ADD COLUMN IF NOT EXISTS motif_rejet text,
  ADD COLUMN IF NOT EXISTS commentaire_validation text,
  ADD COLUMN IF NOT EXISTS cree_par uuid,
  ADD COLUMN IF NOT EXISTS reference_paiement text,
  ADD COLUMN IF NOT EXISTS banque text,
  ADD COLUMN IF NOT EXISTS num_transaction text,
  ADD COLUMN IF NOT EXISTS observations text;

-- ---------- Helper: prochaine référence ----------
CREATE OR REPLACE FUNCTION public._next_ref(_prefix text, _table regclass, _col text)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE v_year text := to_char(now(), 'YYYY'); v_n int; v_sql text;
BEGIN
  v_sql := format(
    'SELECT COALESCE(MAX(NULLIF(regexp_replace(%I, ''.*-'', ''''), '''')::int), 0) FROM %s WHERE %I LIKE %L',
    _col, _table::text, _col, _prefix || '-' || v_year || '-%'
  );
  EXECUTE v_sql INTO v_n;
  RETURN _prefix || '-' || v_year || '-' || lpad((COALESCE(v_n,0) + 1)::text, 5, '0');
END; $$ SET search_path = public;

-- ---------- creer_commande ----------
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
RETURNS SETOF public.commandes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('CMD', 'public.commandes', 'reference');
  v_ligne jsonb;
  v_tva numeric := COALESCE((_payload->>'taux_tva')::numeric, 0);
  v_remise_g numeric := COALESCE((_payload->>'remise_globale_pct')::numeric, 0);
  v_total_ht_brut numeric := 0;
  v_total_remises numeric := 0;
  v_total_ht_net numeric;
  v_remise_g_mnt numeric;
  v_tva_mnt numeric;
  v_ttc numeric;
  v_nb int := 0;
  v_qte int := 0;
  v_qte_l numeric; v_pu numeric; v_rpct numeric; v_rmnt numeric; v_tot numeric;
BEGIN
  INSERT INTO public.commandes(
    reference, client_id, client_nom, etablissement, representant_nom, telephone, ville, adresse,
    observations, statut, remise_globale_pct, taux_tva, exercice_id, depot_id, created_by
  ) VALUES (
    v_ref,
    NULLIF(_payload->>'client_id','')::uuid,
    _payload->>'client_nom',
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    _payload->>'observations',
    'brouillon',
    v_remise_g, v_tva,
    NULLIF(_payload->>'exercice_id','')::uuid,
    NULLIF(_payload->>'depot_id','')::uuid,
    auth.uid()
  ) RETURNING commande_id INTO v_id;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_qte_l := COALESCE((v_ligne->>'quantite')::numeric, 0);
    v_pu    := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
    v_rpct  := COALESCE((v_ligne->>'remise_pct')::numeric, 0);
    v_rmnt  := ROUND(v_qte_l * v_pu * v_rpct / 100, 2);
    v_tot   := ROUND(v_qte_l * v_pu - v_rmnt, 2);
    INSERT INTO public.commande_lignes(
      commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire,
      remise_pct, montant_remise, total_ligne, total_ht_ligne
    ) VALUES (
      v_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      v_ligne->>'reference_produit',
      COALESCE(v_ligne->>'designation',''),
      v_qte_l::int, v_pu, v_rpct, v_rmnt, v_tot, v_tot
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
    nb_produits = v_nb, total_quantite = v_qte,
    total_ht_brut = v_total_ht_brut, total_remises_lignes = v_total_remises,
    total_ht_net = v_total_ht_net, remise_globale_montant = v_remise_g_mnt,
    montant_tva = v_tva_mnt, montant_ttc = v_ttc,
    net_a_payer = v_ttc, montant_total = v_ttc
  WHERE commande_id = v_id;

  RETURN QUERY SELECT * FROM public.commandes WHERE commande_id = v_id;
END; $$;

-- ---------- modifier_commande ----------
CREATE OR REPLACE FUNCTION public.modifier_commande(_commande_id uuid, _payload jsonb)
RETURNS SETOF public.commandes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM public.commandes WHERE commande_id = _commande_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_statut NOT IN ('brouillon','soumise') THEN
    RAISE EXCEPTION 'Commande non modifiable (statut=%)', v_statut;
  END IF;

  UPDATE public.commandes SET
    client_id = COALESCE(NULLIF(_payload->>'client_id','')::uuid, client_id),
    client_nom = COALESCE(_payload->>'client_nom', client_nom),
    etablissement = COALESCE(_payload->>'etablissement', etablissement),
    representant_nom = COALESCE(_payload->>'representant_nom', representant_nom),
    telephone = COALESCE(_payload->>'telephone', telephone),
    ville = COALESCE(_payload->>'ville', ville),
    adresse = COALESCE(_payload->>'adresse', adresse),
    observations = COALESCE(_payload->>'observations', observations),
    depot_id = COALESCE(NULLIF(_payload->>'depot_id','')::uuid, depot_id)
  WHERE commande_id = _commande_id;

  -- Si lignes fournies, remplacer + recalculer via creer_commande logic
  IF _payload ? 'lignes' THEN
    DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;
    DECLARE
      v_ligne jsonb;
      v_tva numeric; v_remise_g numeric;
      v_total_ht_brut numeric := 0; v_total_remises numeric := 0;
      v_total_ht_net numeric; v_remise_g_mnt numeric; v_tva_mnt numeric; v_ttc numeric;
      v_nb int := 0; v_qte int := 0;
      v_qte_l numeric; v_pu numeric; v_rpct numeric; v_rmnt numeric; v_tot numeric;
    BEGIN
      SELECT taux_tva, remise_globale_pct INTO v_tva, v_remise_g FROM public.commandes WHERE commande_id = _commande_id;
      v_tva := COALESCE((_payload->>'taux_tva')::numeric, v_tva);
      v_remise_g := COALESCE((_payload->>'remise_globale_pct')::numeric, v_remise_g);

      FOR v_ligne IN SELECT * FROM jsonb_array_elements(_payload->'lignes') LOOP
        v_qte_l := COALESCE((v_ligne->>'quantite')::numeric, 0);
        v_pu    := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
        v_rpct  := COALESCE((v_ligne->>'remise_pct')::numeric, 0);
        v_rmnt  := ROUND(v_qte_l * v_pu * v_rpct / 100, 2);
        v_tot   := ROUND(v_qte_l * v_pu - v_rmnt, 2);
        INSERT INTO public.commande_lignes(commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire, remise_pct, montant_remise, total_ligne, total_ht_ligne)
        VALUES (_commande_id, NULLIF(v_ligne->>'produit_id','')::uuid, v_ligne->>'reference_produit',
                COALESCE(v_ligne->>'designation',''), v_qte_l::int, v_pu, v_rpct, v_rmnt, v_tot, v_tot);
        v_total_ht_brut := v_total_ht_brut + v_qte_l * v_pu;
        v_total_remises := v_total_remises + v_rmnt;
        v_nb := v_nb + 1; v_qte := v_qte + v_qte_l::int;
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
    END;
  END IF;

  RETURN QUERY SELECT * FROM public.commandes WHERE commande_id = _commande_id;
END; $$;

-- ---------- soumettre_commande ----------
CREATE OR REPLACE FUNCTION public.soumettre_commande(_commande_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.commandes SET statut = 'soumise'
  WHERE commande_id = _commande_id AND statut IN ('brouillon');
  IF NOT FOUND THEN RAISE EXCEPTION 'Commande non soumettable'; END IF;
END; $$;

-- ---------- generer_proforma_commande ----------
CREATE OR REPLACE FUNCTION public.generer_proforma_commande(_commande_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pid uuid;
  v_ref text := public._next_ref('PRO', 'public.proformas', 'reference');
  v_cmd public.commandes;
BEGIN
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  INSERT INTO public.proformas(reference, client_id, client_nom, commande_id, date_proforma, date_validite, montant_total, statut, notes)
  VALUES (v_ref, v_cmd.client_id, v_cmd.client_nom, _commande_id, current_date, current_date + 30, v_cmd.montant_total, 'emise', 'Proforma générée depuis '||v_cmd.reference)
  RETURNING proforma_id INTO v_pid;

  INSERT INTO public.proforma_lignes(proforma_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
  SELECT v_pid, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne
  FROM public.commande_lignes WHERE commande_id = _commande_id;

  RETURN jsonb_build_object('proforma_id', v_pid, 'reference', v_ref);
END; $$;

-- ---------- convertir_proforma_en_commande ----------
CREATE OR REPLACE FUNCTION public.convertir_proforma_en_commande(_proforma_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('CMD', 'public.commandes', 'reference');
  v_p public.proformas;
BEGIN
  SELECT * INTO v_p FROM public.proformas WHERE proforma_id = _proforma_id;
  IF v_p.proforma_id IS NULL THEN RAISE EXCEPTION 'Proforma introuvable'; END IF;

  INSERT INTO public.commandes(reference, client_id, client_nom, statut, montant_total, montant_ttc, net_a_payer, created_by)
  VALUES (v_ref, v_p.client_id, v_p.client_nom, 'brouillon', v_p.montant_total, v_p.montant_total, v_p.montant_total, auth.uid())
  RETURNING commande_id INTO v_id;

  INSERT INTO public.commande_lignes(commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne, total_ht_ligne)
  SELECT v_id, produit_id, reference_produit, COALESCE(designation,''), COALESCE(quantite,0)::int, COALESCE(prix_unitaire,0), COALESCE(total_ligne,0), COALESCE(total_ligne,0)
  FROM public.proforma_lignes WHERE proforma_id = _proforma_id;

  UPDATE public.proformas SET statut = 'convertie', commande_id = v_id WHERE proforma_id = _proforma_id;
  RETURN v_id;
END; $$;

-- ---------- convertir_commande_en_bl ----------
CREATE OR REPLACE FUNCTION public.convertir_commande_en_bl(
  _commande_id uuid,
  _nb_colis int,
  _poids_total numeric DEFAULT NULL,
  _transporteur text DEFAULT NULL,
  _adresse_livraison text DEFAULT NULL,
  _signataire text DEFAULT NULL,
  _date_livraison date DEFAULT NULL,
  _decrementer_stock boolean DEFAULT true
) RETURNS TABLE(bl_id uuid, reference text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_bl uuid;
  v_ref text := public._next_ref('BL', 'public.bons_livraison', 'reference');
  v_cmd public.commandes;
  r record;
BEGIN
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  INSERT INTO public.bons_livraison(reference, commande_id, client_id, client_nom, date_emission, statut, exercice_id)
  VALUES (v_ref, _commande_id, v_cmd.client_id, v_cmd.client_nom, current_date, 'a_preparer', v_cmd.exercice_id)
  RETURNING bl_id INTO v_bl;

  UPDATE public.commandes SET statut = 'livraison_en_cours' WHERE commande_id = _commande_id;

  IF _decrementer_stock AND v_cmd.depot_id IS NOT NULL THEN
    FOR r IN SELECT produit_id, quantite FROM public.commande_lignes WHERE commande_id = _commande_id AND produit_id IS NOT NULL LOOP
      UPDATE public.stocks_depots SET quantite = quantite - r.quantite, updated_at = now()
      WHERE produit_id = r.produit_id AND depot_id = v_cmd.depot_id;
      INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie, stock_resultant, origine, document_id, user_id)
      SELECT r.produit_id, v_cmd.depot_id, 'sortie', r.quantite, 0, r.quantite, quantite, 'vente', _commande_id, auth.uid()
      FROM public.stocks_depots WHERE produit_id = r.produit_id AND depot_id = v_cmd.depot_id;
    END LOOP;
  END IF;

  RETURN QUERY SELECT v_bl, v_ref;
END; $$;

-- ---------- valider_commande (statut + facture + BL) ----------
CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
RETURNS TABLE(facture_reference text, bl_reference text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cmd public.commandes;
  v_f_ref text := public._next_ref('FAC', 'public.factures', 'reference');
  v_bl_ref text := public._next_ref('BL', 'public.bons_livraison', 'reference');
  v_bl_id uuid;
BEGIN
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_cmd.statut = 'validee' THEN RAISE EXCEPTION 'Commande déjà validée'; END IF;

  INSERT INTO public.factures(reference, client_id, client_nom, commande_id, exercice_id, date_facture, date_echeance, montant_total, statut)
  VALUES (v_f_ref, v_cmd.client_id, v_cmd.client_nom, _commande_id, v_cmd.exercice_id, current_date, current_date + 30, v_cmd.montant_total, 'impayee');

  INSERT INTO public.bons_livraison(reference, commande_id, client_id, client_nom, date_emission, statut, exercice_id)
  VALUES (v_bl_ref, _commande_id, v_cmd.client_id, v_cmd.client_nom, current_date, 'a_preparer', v_cmd.exercice_id)
  RETURNING bl_id INTO v_bl_id;

  UPDATE public.commandes SET statut = 'validee' WHERE commande_id = _commande_id;

  RETURN QUERY SELECT v_f_ref, v_bl_ref;
END; $$;

-- ---------- supprimer_commande_definitif ----------
CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ref text; v_lignes int; v_factures int; v_bls int; v_paiements int;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference INTO v_ref FROM public.commandes WHERE commande_id = _commande_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  SELECT count(*) INTO v_paiements FROM public.paiements p
    JOIN public.factures f ON f.facture_id = p.facture_id
    WHERE f.commande_id = _commande_id;
  DELETE FROM public.paiements WHERE facture_id IN (SELECT facture_id FROM public.factures WHERE commande_id = _commande_id);
  SELECT count(*) INTO v_factures FROM public.factures WHERE commande_id = _commande_id;
  DELETE FROM public.factures WHERE commande_id = _commande_id;
  SELECT count(*) INTO v_bls FROM public.bons_livraison WHERE commande_id = _commande_id;
  DELETE FROM public.bons_livraison WHERE commande_id = _commande_id;
  SELECT count(*) INTO v_lignes FROM public.commande_lignes WHERE commande_id = _commande_id;
  DELETE FROM public.commandes WHERE commande_id = _commande_id;

  RETURN jsonb_build_object(
    'commande_id', _commande_id, 'reference', v_ref, 'motif', _motif,
    'lignes_supprimees', v_lignes, 'factures_supprimees', v_factures,
    'bls_supprimes', v_bls, 'paiements_supprimes', v_paiements
  );
END; $$;

-- ---------- supprimer_facture_definitif ----------
CREATE OR REPLACE FUNCTION public.supprimer_facture_definitif(_facture_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ref text; v_p int;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference INTO v_ref FROM public.factures WHERE facture_id = _facture_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Facture introuvable'; END IF;
  SELECT count(*) INTO v_p FROM public.paiements WHERE facture_id = _facture_id;
  DELETE FROM public.paiements WHERE facture_id = _facture_id;
  DELETE FROM public.factures WHERE facture_id = _facture_id;
  RETURN jsonb_build_object('facture_id', _facture_id, 'reference', v_ref, 'motif', _motif, 'paiements_supprimes', v_p);
END; $$;

-- ---------- supprimer_proforma_definitif ----------
CREATE OR REPLACE FUNCTION public.supprimer_proforma_definitif(_proforma_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ref text;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference INTO v_ref FROM public.proformas WHERE proforma_id = _proforma_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Proforma introuvable'; END IF;
  DELETE FROM public.proformas WHERE proforma_id = _proforma_id;
  RETURN jsonb_build_object('proforma_id', _proforma_id, 'reference', v_ref, 'motif', _motif);
END; $$;

-- ---------- enregistrer_paiement ----------
CREATE OR REPLACE FUNCTION public.enregistrer_paiement(_payload jsonb)
RETURNS SETOF public.paiements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('PAI', 'public.paiements', 'reference');
  v_facture_id uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_montant numeric := COALESCE((_payload->>'montant')::numeric, 0);
  v_client_nom text;
  v_new_paye numeric; v_total numeric;
BEGIN
  IF v_facture_id IS NULL THEN RAISE EXCEPTION 'facture_id obligatoire'; END IF;
  SELECT client_nom, montant_total, montant_paye INTO v_client_nom, v_total, v_new_paye
    FROM public.factures WHERE facture_id = v_facture_id;
  IF v_total IS NULL THEN RAISE EXCEPTION 'Facture introuvable'; END IF;

  INSERT INTO public.paiements(
    reference, facture_id, client_nom, date_paiement, montant, mode_paiement,
    statut, notes, reference_paiement, banque, num_transaction, observations, cree_par
  ) VALUES (
    v_ref, v_facture_id, v_client_nom,
    COALESCE((_payload->>'date_paiement')::date, current_date),
    v_montant,
    COALESCE(_payload->>'mode_paiement','especes'),
    'valide',
    _payload->>'notes',
    _payload->>'reference_paiement',
    _payload->>'banque',
    _payload->>'num_transaction',
    _payload->>'observations',
    auth.uid()
  ) RETURNING paiement_id INTO v_id;

  v_new_paye := COALESCE(v_new_paye,0) + v_montant;
  UPDATE public.factures SET
    montant_paye = v_new_paye,
    statut = CASE WHEN v_new_paye >= v_total THEN 'payee' WHEN v_new_paye > 0 THEN 'partielle' ELSE 'impayee' END
  WHERE facture_id = v_facture_id;

  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id = v_id;
END; $$;

-- ---------- annuler_paiement ----------
CREATE OR REPLACE FUNCTION public.annuler_paiement(_paiement_id uuid, _raison text, _notes text DEFAULT NULL)
RETURNS SETOF public.paiements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.paiements; v_new_paye numeric; v_total numeric;
BEGIN
  SELECT * INTO v_row FROM public.paiements WHERE paiement_id = _paiement_id;
  IF v_row.paiement_id IS NULL THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;
  IF v_row.statut = 'annule' THEN RAISE EXCEPTION 'Déjà annulé'; END IF;

  INSERT INTO public.paiement_annulations_audit(paiement_id, facture_id, annule_par, raison, notes, montant_annule)
  VALUES (_paiement_id, v_row.facture_id, auth.uid(), COALESCE(_raison,''), _notes, v_row.montant);

  UPDATE public.paiements SET statut = 'annule' WHERE paiement_id = _paiement_id;

  IF v_row.facture_id IS NOT NULL THEN
    SELECT montant_total, GREATEST(COALESCE(montant_paye,0) - v_row.montant, 0) INTO v_total, v_new_paye
      FROM public.factures WHERE facture_id = v_row.facture_id;
    UPDATE public.factures SET
      montant_paye = v_new_paye,
      statut = CASE WHEN v_new_paye >= v_total THEN 'payee' WHEN v_new_paye > 0 THEN 'partielle' ELSE 'impayee' END
    WHERE facture_id = v_row.facture_id;
  END IF;

  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id = _paiement_id;
END; $$;

-- ---------- supprimer_paiement_definitif ----------
CREATE OR REPLACE FUNCTION public.supprimer_paiement_definitif(_paiement_id uuid, _motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.paiements; v_new_paye numeric; v_total numeric;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_row FROM public.paiements WHERE paiement_id = _paiement_id;
  IF v_row.paiement_id IS NULL THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;

  DELETE FROM public.paiements WHERE paiement_id = _paiement_id;

  IF v_row.facture_id IS NOT NULL AND v_row.statut <> 'annule' THEN
    SELECT montant_total, GREATEST(COALESCE(montant_paye,0) - v_row.montant, 0) INTO v_total, v_new_paye
      FROM public.factures WHERE facture_id = v_row.facture_id;
    UPDATE public.factures SET
      montant_paye = v_new_paye,
      statut = CASE WHEN v_new_paye >= v_total THEN 'payee' WHEN v_new_paye > 0 THEN 'partielle' ELSE 'impayee' END
    WHERE facture_id = v_row.facture_id;
  END IF;

  RETURN jsonb_build_object('paiement_id', _paiement_id, 'reference', v_row.reference, 'motif', _motif);
END; $$;

-- ---------- valider_paiement / rejeter_paiement ----------
CREATE OR REPLACE FUNCTION public.valider_paiement(_paiement_id uuid, _commentaire text DEFAULT NULL)
RETURNS SETOF public.paiements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.paiements SET statut='valide', valide_par=auth.uid(), valide_le=now(), commentaire_validation=_commentaire
  WHERE paiement_id=_paiement_id AND statut IN ('en_attente','en_attente_validation');
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement non validable'; END IF;
  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id=_paiement_id;
END; $$;

CREATE OR REPLACE FUNCTION public.rejeter_paiement(_paiement_id uuid, _motif text)
RETURNS SETOF public.paiements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.paiements SET statut='rejete', rejete_par=auth.uid(), rejete_le=now(), motif_rejet=_motif
  WHERE paiement_id=_paiement_id AND statut IN ('en_attente','en_attente_validation');
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement non rejetable'; END IF;
  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id=_paiement_id;
END; $$;

-- ---------- factures_impayees_client ----------
CREATE OR REPLACE FUNCTION public.factures_impayees_client(_client_id uuid)
RETURNS TABLE(facture_id uuid, reference text, date_facture date, montant_total numeric, montant_paye numeric, solde numeric, statut text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT facture_id, reference, date_facture, montant_total, COALESCE(montant_paye,0),
         (montant_total - COALESCE(montant_paye,0))::numeric AS solde, statut
  FROM public.factures
  WHERE client_id = _client_id AND statut IN ('impayee','partielle')
  ORDER BY date_facture ASC;
$$;

-- ---------- factures_list_paginated ----------
CREATE OR REPLACE FUNCTION public.factures_list_paginated(
  _q text DEFAULT NULL, _statut text DEFAULT NULL,
  _date_du date DEFAULT NULL, _date_au date DEFAULT NULL,
  _exercice_id uuid DEFAULT NULL,
  _page int DEFAULT 1, _page_size int DEFAULT 20
) RETURNS TABLE(items jsonb, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_offset int := (GREATEST(_page,1)-1) * GREATEST(_page_size,1); v_total bigint;
BEGIN
  SELECT count(*) INTO v_total FROM public.factures f
   WHERE (_exercice_id IS NULL OR f.exercice_id = _exercice_id)
     AND (_statut IS NULL OR f.statut = _statut)
     AND (_date_du IS NULL OR f.date_facture >= _date_du)
     AND (_date_au IS NULL OR f.date_facture <= _date_au)
     AND (_q IS NULL OR f.reference ILIKE '%'||_q||'%' OR COALESCE(f.client_nom,'') ILIKE '%'||_q||'%');

  RETURN QUERY
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC), '[]'::jsonb), v_total
  FROM (
    SELECT * FROM public.factures f
     WHERE (_exercice_id IS NULL OR f.exercice_id = _exercice_id)
       AND (_statut IS NULL OR f.statut = _statut)
       AND (_date_du IS NULL OR f.date_facture >= _date_du)
       AND (_date_au IS NULL OR f.date_facture <= _date_au)
       AND (_q IS NULL OR f.reference ILIKE '%'||_q||'%' OR COALESCE(f.client_nom,'') ILIKE '%'||_q||'%')
     ORDER BY f.created_at DESC
     LIMIT GREATEST(_page_size,1) OFFSET v_offset
  ) x;
END; $$;

-- ---------- GRANT execution ----------
GRANT EXECUTE ON FUNCTION public.creer_commande(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.modifier_commande(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.soumettre_commande(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generer_proforma_commande(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.convertir_proforma_en_commande(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.convertir_commande_en_bl(uuid, int, numeric, text, text, text, date, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.valider_commande(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supprimer_commande_definitif(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supprimer_facture_definitif(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supprimer_proforma_definitif(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enregistrer_paiement(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.annuler_paiement(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supprimer_paiement_definitif(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.valider_paiement(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rejeter_paiement(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.factures_impayees_client(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.factures_list_paginated(text, text, date, date, uuid, int, int) TO authenticated;
