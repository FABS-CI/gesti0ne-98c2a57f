-- Lot 5 : durcissement RPC Ventes/Livraisons/Colisage/Paiements/Incidents/Retours/Specimens

CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
 RETURNS SETOF commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  PERFORM public.assert_permission('commandes.creer');

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
END; $function$;

CREATE OR REPLACE FUNCTION public.modifier_commande(_commande_id uuid, _payload jsonb)
 RETURNS SETOF commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_statut text;
BEGIN
  PERFORM public.assert_permission('commandes.modifier');

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
END; $function$;

CREATE OR REPLACE FUNCTION public.soumettre_commande(_commande_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('commandes.soumettre');

  UPDATE public.commandes SET statut = 'soumise'
  WHERE commande_id = _commande_id AND statut IN ('brouillon');
  IF NOT FOUND THEN RAISE EXCEPTION 'Commande non soumettable'; END IF;
END; $function$;

CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
 RETURNS TABLE(facture_reference text, bl_reference text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_cmd public.commandes;
  v_f_ref text := public._next_ref('FAC', 'public.factures', 'reference');
  v_bl_ref text := public._next_ref('BL', 'public.bons_livraison', 'reference');
  v_bl_id uuid;
BEGIN
  PERFORM public.assert_permission('commandes.valider');

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
END; $function$;

CREATE OR REPLACE FUNCTION public.convertir_commande_en_bl(_commande_id uuid, _nb_colis integer, _poids_total numeric DEFAULT NULL::numeric, _transporteur text DEFAULT NULL::text, _adresse_livraison text DEFAULT NULL::text, _signataire text DEFAULT NULL::text, _date_livraison date DEFAULT NULL::date, _decrementer_stock boolean DEFAULT true)
 RETURNS TABLE(bl_id uuid, reference text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bl uuid;
  v_ref text := public._next_ref('BL', 'public.bons_livraison', 'reference');
  v_cmd public.commandes;
  r record;
BEGIN
  PERFORM public.assert_permission('commandes.convertir_en_bl');

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
END; $function$;

CREATE OR REPLACE FUNCTION public.convertir_proforma_en_commande(_proforma_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('CMD', 'public.commandes', 'reference');
  v_p public.proformas;
  v_ex uuid;
BEGIN
  PERFORM public.assert_permission('proformas.convertir_en_commande');

  SELECT * INTO v_p FROM public.proformas WHERE proforma_id = _proforma_id;
  IF v_p.proforma_id IS NULL THEN RAISE EXCEPTION 'Proforma introuvable'; END IF;

  v_ex := public._resolve_exercice_id(current_date);
  IF v_ex IS NULL THEN
    SELECT exercice_id INTO v_ex FROM public.exercices_comptables WHERE is_actif ORDER BY date_debut DESC LIMIT 1;
  END IF;

  INSERT INTO public.commandes(reference, client_id, client_nom, statut, montant_total, montant_ttc, net_a_payer, created_by, exercice_id)
  VALUES (v_ref, v_p.client_id, v_p.client_nom, 'brouillon', v_p.montant_total, v_p.montant_total, v_p.montant_total, auth.uid(), v_ex)
  RETURNING commande_id INTO v_id;

  INSERT INTO public.commande_lignes(commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne, total_ht_ligne)
  SELECT v_id, produit_id, reference_produit, COALESCE(designation,''), COALESCE(quantite,0)::int, COALESCE(prix_unitaire,0), COALESCE(total_ligne,0), COALESCE(total_ligne,0)
  FROM public.proforma_lignes WHERE proforma_id = _proforma_id;

  UPDATE public.proformas SET statut = 'convertie', commande_id = v_id WHERE proforma_id = _proforma_id;
  RETURN v_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.generer_proforma_commande(_commande_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pid uuid;
  v_ref text := public._next_ref('PRO', 'public.proformas', 'reference');
  v_cmd public.commandes;
BEGIN
  PERFORM public.assert_permission('commandes.generer_proforma');

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  INSERT INTO public.proformas(reference, client_id, client_nom, commande_id, date_proforma, date_validite, montant_total, statut, notes)
  VALUES (v_ref, v_cmd.client_id, v_cmd.client_nom, _commande_id, current_date, current_date + 30, v_cmd.montant_total, 'emise', 'Proforma générée depuis '||v_cmd.reference)
  RETURNING proforma_id INTO v_pid;

  INSERT INTO public.proforma_lignes(proforma_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
  SELECT v_pid, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne
  FROM public.commande_lignes WHERE commande_id = _commande_id;

  RETURN jsonb_build_object('proforma_id', v_pid, 'reference', v_ref);
END; $function$;

CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
 RETURNS SETOF retours
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('RET','public.retours','reference');
  v_num text := v_ref;
  v_l jsonb;
  v_qte_totale numeric := 0;
  v_nb_produits int := 0;
  v_montant numeric := 0;
  v_client_nom text;
  v_created_by_nom text;
  v_commande_id uuid;
BEGIN
  PERFORM public.assert_permission('retours.creer');

  IF NULLIF(_payload->>'client_id','') IS NOT NULL THEN
    SELECT nom INTO v_client_nom FROM public.clients WHERE client_id = (_payload->>'client_id')::uuid;
  END IF;

  v_created_by_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  IF NULLIF(_payload->>'facture_id','') IS NOT NULL THEN
    SELECT commande_id INTO v_commande_id
    FROM public.factures WHERE facture_id = (_payload->>'facture_id')::uuid;
  END IF;

  INSERT INTO public.retours(
    reference, numero, commande_id, client_id, client_nom, facture_id, livraison_id,
    etablissement, representant_nom, telephone, ville, adresse, depot_id,
    date_retour, statut, motif, notes, observations,
    total_quantite, nb_produits, montant,
    created_by, created_by_nom
  ) VALUES (
    v_ref, v_num, v_commande_id,
    NULLIF(_payload->>'client_id','')::uuid,
    COALESCE(_payload->>'client_nom', v_client_nom),
    NULLIF(_payload->>'facture_id','')::uuid,
    NULLIF(_payload->>'livraison_id','')::uuid,
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    NULLIF(_payload->>'depot_id','')::uuid,
    COALESCE((_payload->>'date_retour')::date, current_date),
    'accepte',
    _payload->>'motif',
    _payload->>'notes',
    _payload->>'observations',
    0, 0, 0,
    auth.uid(), v_created_by_nom
  )
  RETURNING retour_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.retour_lignes(
      retour_id, produit_id, reference_produit, designation, quantite, motif
    ) VALUES (
      v_id,
      NULLIF(v_l->>'produit_id','')::uuid,
      v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''),
      COALESCE((v_l->>'quantite')::numeric, 0),
      v_l->>'motif'
    );
    v_qte_totale := v_qte_totale + COALESCE((v_l->>'quantite')::numeric, 0);
    v_nb_produits := v_nb_produits + 1;
  END LOOP;

  UPDATE public.retours
     SET total_quantite = v_qte_totale,
         nb_produits    = v_nb_produits
   WHERE retour_id = v_id;

  RETURN QUERY SELECT * FROM public.retours WHERE retour_id = v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.annuler_retour(_retour_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('retours.annuler');

  UPDATE public.retours SET statut = 'annule', notes = COALESCE(_motif, notes)
   WHERE retour_id = _retour_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
 RETURNS SETOF specimens
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('SPC','public.specimens','reference');
  v_num text := v_ref;
  v_l jsonb;
  v_qte_totale numeric := 0;
  v_nb_produits int := 0;
  v_client_nom text;
  v_created_by_nom text;
BEGIN
  PERFORM public.assert_permission('specimens.creer');

  IF NULLIF(_payload->>'client_id','') IS NOT NULL THEN
    SELECT nom INTO v_client_nom FROM public.clients WHERE client_id = (_payload->>'client_id')::uuid;
  END IF;
  v_created_by_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  INSERT INTO public.specimens(
    reference, numero, client_id, client_nom,
    etablissement, representant_nom, telephone, ville, adresse,
    donneur_nom, motif, observations,
    date_envoi, statut,
    total_quantite, nb_produits,
    depot_id, created_by,
    gestionnaire_id, gestionnaire_nom,
    quantite, designation
  ) VALUES (
    v_ref, v_num,
    NULLIF(_payload->>'client_id','')::uuid,
    COALESCE(_payload->>'client_nom', v_client_nom),
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    _payload->>'donneur_nom',
    _payload->>'motif',
    _payload->>'observations',
    COALESCE((_payload->>'date_envoi')::date, current_date),
    'enregistre',
    0, 0,
    NULLIF(_payload->>'depot_id','')::uuid,
    auth.uid(),
    auth.uid(), v_created_by_nom,
    0, ''
  )
  RETURNING specimen_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.specimen_lignes(
      specimen_id, produit_id, reference_produit, designation, quantite
    ) VALUES (
      v_id,
      NULLIF(v_l->>'produit_id','')::uuid,
      v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''),
      COALESCE((v_l->>'quantite')::numeric, 0)
    );
    v_qte_totale := v_qte_totale + COALESCE((v_l->>'quantite')::numeric, 0);
    v_nb_produits := v_nb_produits + 1;
  END LOOP;

  UPDATE public.specimens
     SET total_quantite = v_qte_totale,
         nb_produits    = v_nb_produits
   WHERE specimen_id = v_id;

  RETURN QUERY SELECT * FROM public.specimens WHERE specimen_id = v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.annuler_specimen(_specimen_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('specimens.annuler');

  UPDATE public.specimens SET statut = 'annule', notes = COALESCE(_motif, notes)
   WHERE specimen_id = _specimen_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.enregistrer_paiement(_payload jsonb)
 RETURNS SETOF paiements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('PAI', 'public.paiements', 'reference');
  v_facture_id uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_montant numeric := COALESCE((_payload->>'montant')::numeric, 0);
  v_client_nom text;
  v_new_paye numeric; v_total numeric;
  v_date date := COALESCE((_payload->>'date_paiement')::date, current_date);
  v_ex uuid;
BEGIN
  PERFORM public.assert_permission('paiements.creer');

  IF v_facture_id IS NULL THEN RAISE EXCEPTION 'facture_id obligatoire'; END IF;
  SELECT client_nom, montant_total, montant_paye INTO v_client_nom, v_total, v_new_paye
    FROM public.factures WHERE facture_id = v_facture_id;
  IF v_total IS NULL THEN RAISE EXCEPTION 'Facture introuvable'; END IF;

  v_ex := public._resolve_exercice_id(v_date);
  IF v_ex IS NULL THEN
    SELECT exercice_id INTO v_ex FROM public.exercices_comptables WHERE is_actif ORDER BY date_debut DESC LIMIT 1;
  END IF;

  INSERT INTO public.paiements(
    reference, facture_id, client_nom, date_paiement, montant, mode_paiement,
    statut, notes, reference_paiement, banque, num_transaction, observations, cree_par, exercice_id
  ) VALUES (
    v_ref, v_facture_id, v_client_nom, v_date, v_montant,
    COALESCE(_payload->>'mode_paiement','especes'), 'valide',
    _payload->>'notes', _payload->>'reference_paiement', _payload->>'banque',
    _payload->>'num_transaction', _payload->>'observations', auth.uid(), v_ex
  ) RETURNING paiement_id INTO v_id;

  v_new_paye := COALESCE(v_new_paye,0) + v_montant;
  UPDATE public.factures SET
    montant_paye = v_new_paye,
    statut = CASE WHEN v_new_paye >= v_total THEN 'payee' WHEN v_new_paye > 0 THEN 'partielle' ELSE 'impayee' END
  WHERE facture_id = v_facture_id;

  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id = v_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.valider_paiement(_paiement_id uuid, _commentaire text DEFAULT NULL::text)
 RETURNS SETOF paiements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('paiements.valider');

  UPDATE public.paiements SET statut='valide', valide_par=auth.uid(), valide_le=now(), commentaire_validation=_commentaire
  WHERE paiement_id=_paiement_id AND statut IN ('en_attente','en_attente_validation');
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement non validable'; END IF;
  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id=_paiement_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.rejeter_paiement(_paiement_id uuid, _motif text)
 RETURNS SETOF paiements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('paiements.rejeter');

  UPDATE public.paiements SET statut='rejete', rejete_par=auth.uid(), rejete_le=now(), motif_rejet=_motif
  WHERE paiement_id=_paiement_id AND statut IN ('en_attente','en_attente_validation');
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement non rejetable'; END IF;
  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id=_paiement_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.annuler_paiement(_paiement_id uuid, _raison text, _notes text DEFAULT NULL::text)
 RETURNS SETOF paiements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_row public.paiements; v_new_paye numeric; v_total numeric;
BEGIN
  PERFORM public.assert_permission('paiements.annuler');

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
END; $function$;

CREATE OR REPLACE FUNCTION public.creer_colisage(_bl_id uuid, _payload jsonb)
 RETURNS SETOF colis
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_nb integer := COALESCE((_payload->>'nb_cartons')::int, 1);
  i integer;
  v_ref text;
  v_bl_ref text;
BEGIN
  PERFORM public.assert_permission('colisage.creer');

  DELETE FROM public.colis WHERE bl_id = _bl_id;
  SELECT reference INTO v_bl_ref FROM public.bons_livraison WHERE bl_id = _bl_id;

  FOR i IN 1..v_nb LOOP
    v_ref := COALESCE(v_bl_ref, 'BL') || '-C' || lpad(i::text, 3, '0');
    INSERT INTO public.colis(
      bl_id, reference, numero_carton, nb_cartons,
      responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule,
      quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone,
      observations, date_colisage
    ) VALUES (
      _bl_id, v_ref, i, v_nb,
      _payload->>'responsable_nom', _payload->>'mode_acheminement',
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      _payload->>'observations',
      COALESCE((_payload->>'date_colisage')::timestamptz, now())
    );
  END LOOP;

  UPDATE public.bons_livraison SET statut = 'colisage_termine' WHERE bl_id = _bl_id;
  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END;
$function$;

CREATE OR REPLACE FUNCTION public.creer_colisage_manuel(_bl_id uuid, _payload jsonb, _cartons jsonb)
 RETURNS SETOF colis
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_carton jsonb;
  v_ligne jsonb;
  v_colis_id uuid;
  v_ref text;
  v_bl_ref text;
  v_num integer := 0;
  v_nb integer := jsonb_array_length(_cartons);
BEGIN
  PERFORM public.assert_permission('colisage.creer');

  DELETE FROM public.colis WHERE bl_id = _bl_id;
  SELECT reference INTO v_bl_ref FROM public.bons_livraison WHERE bl_id = _bl_id;

  FOR v_carton IN SELECT * FROM jsonb_array_elements(_cartons) LOOP
    v_num := v_num + 1;
    v_ref := COALESCE(v_bl_ref, 'BL') || '-C' || lpad(v_num::text, 3, '0');
    INSERT INTO public.colis(
      bl_id, reference, numero_carton, nb_cartons,
      responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule,
      quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone,
      poids, observations, date_colisage
    ) VALUES (
      _bl_id, v_ref, v_num, v_nb,
      _payload->>'responsable_nom', _payload->>'mode_acheminement',
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      COALESCE((v_carton->>'poids')::numeric, 0),
      COALESCE(v_carton->>'observations', _payload->>'observations'),
      COALESCE((_payload->>'date_colisage')::timestamptz, now())
    ) RETURNING colis_id INTO v_colis_id;

    FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_carton->'lignes') LOOP
      INSERT INTO public.colis_lignes(colis_id, produit_id, designation, reference_produit, quantite)
      VALUES (
        v_colis_id,
        NULLIF(v_ligne->>'produit_id','')::uuid,
        v_ligne->>'designation',
        v_ligne->>'reference_produit',
        COALESCE((v_ligne->>'quantite')::numeric, 0)
      );
    END LOOP;
  END LOOP;

  UPDATE public.bons_livraison SET statut = 'colisage_termine' WHERE bl_id = _bl_id;
  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END;
$function$;

CREATE OR REPLACE FUNCTION public.annuler_colisage(_bl_id uuid, _motif text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('colisage.annuler');

  INSERT INTO public.colis_statut_historique(bl_id, ancien_statut, nouveau_statut, motif, user_id)
  SELECT _bl_id, 'colisage_termine', 'annule', _motif, auth.uid();
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  UPDATE public.bons_livraison SET statut = 'a_preparer' WHERE bl_id = _bl_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.deverrouiller_colisage(_bl_id uuid, _motif text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('colisage.deverrouiller');

  UPDATE public.bons_livraison SET statut = 'colisage_en_cours' WHERE bl_id = _bl_id;
  INSERT INTO public.colis_statut_historique(bl_id, ancien_statut, nouveau_statut, motif, user_id)
  VALUES (_bl_id, 'colisage_termine', 'colisage_en_cours', _motif, auth.uid());
END;
$function$;

CREATE OR REPLACE FUNCTION public.modifier_colis_lignes(_colis_id uuid, _lignes jsonb, _motif text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ligne jsonb;
BEGIN
  PERFORM public.assert_permission('colisage.modifier');

  DELETE FROM public.colis_lignes WHERE colis_id = _colis_id;
  FOR v_ligne IN SELECT * FROM jsonb_array_elements(_lignes) LOOP
    INSERT INTO public.colis_lignes(colis_id, produit_id, designation, reference_produit, quantite)
    VALUES (
      _colis_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      v_ligne->>'designation',
      v_ligne->>'reference_produit',
      COALESCE((v_ligne->>'quantite')::numeric, 0)
    );
  END LOOP;

  INSERT INTO public.colis_statut_historique(colis_id, ancien_statut, nouveau_statut, motif, user_id)
  VALUES (_colis_id, 'modifie', 'modifie', _motif, auth.uid());
END;
$function$;

CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
 RETURNS SETOF incidents
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('INC','public.incidents','reference');
  v_l jsonb; v_qte numeric := 0; v_nb int := 0; v_nom text;
BEGIN
  PERFORM public.assert_permission('incidents.creer');

  v_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  INSERT INTO public.incidents(
    reference, numero, type_incident, gravite, description,
    date_incident, statut, motif, observations, depot_id,
    responsable_id, responsable_nom, total_quantite, nb_produits, created_by
  ) VALUES (
    v_ref, v_ref,
    COALESCE(_payload->>'type_incident', 'autre'),
    COALESCE(_payload->>'gravite', 'mineur'),
    _payload->>'description',
    COALESCE((_payload->>'date_incident')::timestamptz, now()),
    'declare',
    _payload->>'motif',
    _payload->>'observations',
    NULLIF(_payload->>'depot_id','')::uuid,
    auth.uid(), v_nom, 0, 0, auth.uid()
  ) RETURNING incident_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.incident_lignes(incident_id, produit_id, reference_produit, designation, quantite)
    VALUES (v_id, NULLIF(v_l->>'produit_id','')::uuid, v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''), COALESCE((v_l->>'quantite')::numeric, 0));
    v_qte := v_qte + COALESCE((v_l->>'quantite')::numeric, 0);
    v_nb := v_nb + 1;
  END LOOP;
  UPDATE public.incidents SET total_quantite = v_qte, nb_produits = v_nb WHERE incident_id = v_id;
  RETURN QUERY SELECT * FROM public.incidents WHERE incident_id = v_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.annuler_incident(_incident_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('incidents.annuler');
 UPDATE public.incidents SET statut='annule' WHERE incident_id = _incident_id; END; $function$;

CREATE OR REPLACE FUNCTION public.livsuivi_avancer(_livraison_id uuid, _etape text, _meta jsonb DEFAULT '{}'::jsonb, _commentaire text DEFAULT NULL::text)
 RETURNS livsuivi_commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_row public.livsuivi_commandes; v_email text;
BEGIN
  PERFORM public.assert_permission('livraisons.avancer_etape');

  UPDATE public.livsuivi_commandes
     SET statut = _etape, derniere_maj = now(),
         cloturee = (_etape IN ('livree','reception_confirmee','retiree_client','livree_locale','non_livre'))
   WHERE id = _livraison_id
   RETURNING * INTO v_row;
  IF v_row.id IS NULL THEN RAISE EXCEPTION 'Livraison introuvable'; END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, meta, user_id, user_nom)
  VALUES (_livraison_id, _etape, _commentaire, COALESCE(_meta,'{}'::jsonb), auth.uid(), v_email);
  RETURN v_row;
END;$function$;

CREATE OR REPLACE FUNCTION public.livsuivi_avancer_masse(_tournee_id uuid, _etape text, _meta jsonb DEFAULT '{}'::jsonb, _filtre_gare text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r record; n integer := 0;
BEGIN
  PERFORM public.assert_permission('livraisons.avancer_masse');

  FOR r IN
    SELECT id FROM public.livsuivi_commandes
    WHERE tournee_id = _tournee_id
      AND (_filtre_gare IS NULL OR gare_destination = _filtre_gare OR gare_depot = _filtre_gare)
      AND NOT cloturee
  LOOP
    PERFORM public.livsuivi_avancer(r.id, _etape, _meta, NULL);
    n := n + 1;
  END LOOP;
  RETURN n;
END;$function$;

CREATE OR REPLACE FUNCTION public.livsuivi_confirmer_reception(_id uuid, _signature_url text DEFAULT NULL::text, _photo_url text DEFAULT NULL::text, _receptionnaire_nom text DEFAULT NULL::text, _receptionnaire_tel text DEFAULT NULL::text, _commentaire text DEFAULT NULL::text)
 RETURNS livsuivi_commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_row public.livsuivi_commandes; v_tournee uuid; v_reste int;
BEGIN
  PERFORM public.assert_permission('livraisons.changer_statut');

  UPDATE public.livsuivi_commandes
     SET statut = 'reception_confirmee', cloturee = true, derniere_maj = now(),
         signature_url = COALESCE(_signature_url, signature_url),
         photo_preuve_url = COALESCE(_photo_url, photo_preuve_url),
         receptionnaire_nom = COALESCE(_receptionnaire_nom, receptionnaire_nom),
         receptionnaire_telephone = COALESCE(_receptionnaire_tel, receptionnaire_telephone),
         commentaire_reception = COALESCE(_commentaire, commentaire_reception),
         heure_livraison = COALESCE(heure_livraison, now())
   WHERE id = _id
   RETURNING * INTO v_row;
  IF v_row.id IS NULL THEN RAISE EXCEPTION 'Livraison introuvable'; END IF;

  INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, meta, user_id)
  VALUES (_id, 'reception_confirmee', _commentaire,
    jsonb_build_object('receptionnaire', _receptionnaire_nom, 'telephone', _receptionnaire_tel),
    auth.uid());

  v_tournee := v_row.tournee_id;
  IF v_tournee IS NOT NULL THEN
    SELECT count(*) INTO v_reste FROM public.livsuivi_commandes
     WHERE tournee_id = v_tournee AND NOT cloturee;
    IF v_reste = 0 THEN
      UPDATE public.tournees SET statut = 'terminee' WHERE tournee_id = v_tournee;
    END IF;
  END IF;
  RETURN v_row;
END;$function$;

CREATE OR REPLACE FUNCTION public.valider_decaissement_tournee(_tournee_id uuid, _mode_reglement text DEFAULT NULL::text, _commentaire text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('tournees.valider_couts');

  UPDATE public.tournees SET validation_statut = 'valide',
    mode_reglement = COALESCE(_mode_reglement, mode_reglement),
    validation_commentaire = COALESCE(_commentaire, validation_commentaire),
    validation_at = now(), validation_by = auth.uid()
  WHERE tournee_id = _tournee_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.refuser_tournee_couts(_tournee_id uuid, _motif text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('tournees.refuser_couts');

  UPDATE public.tournees SET validation_statut = 'refuse',
    validation_commentaire = _motif, validation_at = now(), validation_by = auth.uid()
  WHERE tournee_id = _tournee_id;
END; $function$;