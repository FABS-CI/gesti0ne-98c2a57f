
-- 1. Modify creer_commande to auto-generate proforma + set en_attente_validation
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
 RETURNS commandes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_cmd public.commandes; v_l jsonb; v_client record; v_nom text;
  v_depot uuid := public.resolve_depot_sortie(NULLIF(_payload->>'depot_id','')::uuid, 'commandes');
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  SELECT * INTO v_client FROM public.clients WHERE client_id=(_payload->>'client_id')::uuid;
  v_nom := COALESCE(v_client.nom,_payload->>'client_nom');
  INSERT INTO public.commandes(client_id,client_nom,etablissement,representant_nom,telephone,ville,adresse,
    observations,date_commande,remise_globale_pct,taux_tva,depot_id,created_by,created_by_nom,statut,numero)
  VALUES((_payload->>'client_id')::uuid,v_nom,_payload->>'etablissement',_payload->>'representant_nom',
    _payload->>'telephone',_payload->>'ville',_payload->>'adresse',_payload->>'observations',
    COALESCE((_payload->>'date_commande')::date,current_date),
    COALESCE((_payload->>'remise_globale_pct')::numeric,0),
    COALESCE((_payload->>'taux_tva')::numeric,0),v_depot,auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'),
    'en_attente_validation','CMD-'||to_char(now(),'YYYYMMDD-HH24MISS')) RETURNING * INTO v_cmd;
  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.commande_lignes(commande_id,produit_id,reference_produit,designation,quantite,
      prix_unitaire,remise_pct,montant_remise,total_ht_ligne,total_ligne)
    VALUES(v_cmd.commande_id,NULLIF(v_l->>'produit_id','')::uuid,v_l->>'reference_produit',
      v_l->>'designation',COALESCE((v_l->>'quantite')::int,1),
      COALESCE((v_l->>'prix_unitaire')::numeric,0),COALESCE((v_l->>'remise_pct')::numeric,0),
      (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*COALESCE((v_l->>'remise_pct')::numeric,0)/100),
      (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*(1-COALESCE((v_l->>'remise_pct')::numeric,0)/100)),
      (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*(1-COALESCE((v_l->>'remise_pct')::numeric,0)/100)));
  END LOOP;
  PERFORM public.recalc_commande(v_cmd.commande_id);
  -- AUTO Proforma génération
  PERFORM public.generer_proforma_commande(v_cmd.commande_id);
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd.commande_id;
  RETURN v_cmd;
END $function$;

-- 2. New RPC enregistrer_paiement
CREATE OR REPLACE FUNCTION public.enregistrer_paiement(_payload jsonb)
 RETURNS paiements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_p public.paiements;
  v_fac record;
  v_montant numeric;
  v_total_paye numeric;
  v_nouveau_statut text;
  v_notes text;
  v_ref text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée pour enregistrer un paiement';
  END IF;

  v_montant := COALESCE((_payload->>'montant')::numeric, 0);
  IF v_montant <= 0 THEN RAISE EXCEPTION 'Le montant doit être positif'; END IF;
  IF (_payload->>'facture_id') IS NULL OR _payload->>'facture_id' = '' THEN
    RAISE EXCEPTION 'Facture obligatoire';
  END IF;

  SELECT * INTO v_fac FROM public.factures WHERE facture_id=(_payload->>'facture_id')::uuid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Facture introuvable'; END IF;

  v_notes := COALESCE(_payload->>'observations','');
  IF (_payload->>'banque') IS NOT NULL AND _payload->>'banque' <> '' THEN
    v_notes := v_notes || E'\nBanque: ' || (_payload->>'banque');
  END IF;
  IF (_payload->>'num_transaction') IS NOT NULL AND _payload->>'num_transaction' <> '' THEN
    v_notes := v_notes || E'\nN° transaction: ' || (_payload->>'num_transaction');
  END IF;
  IF (_payload->>'reference_paiement') IS NOT NULL AND _payload->>'reference_paiement' <> '' THEN
    v_notes := v_notes || E'\nRéférence: ' || (_payload->>'reference_paiement');
  END IF;

  v_ref := 'PAY-'||to_char(now(),'YYYYMMDD-HH24MISS');

  INSERT INTO public.paiements(reference, facture_id, client_nom, date_paiement, montant, mode_paiement, statut, notes)
  VALUES(v_ref, v_fac.facture_id, v_fac.client_nom,
    COALESCE((_payload->>'date_paiement')::date, current_date),
    v_montant,
    COALESCE(_payload->>'mode_paiement','especes'),
    'valide',
    NULLIF(trim(v_notes), ''))
  RETURNING * INTO v_p;

  v_total_paye := COALESCE(v_fac.montant_paye, 0) + v_montant;
  IF v_total_paye >= COALESCE(v_fac.montant_total, 0) THEN
    v_nouveau_statut := 'payee';
  ELSIF v_total_paye > 0 THEN
    v_nouveau_statut := 'partielle';
  ELSE
    v_nouveau_statut := 'impayee';
  END IF;

  UPDATE public.factures
     SET montant_paye = v_total_paye,
         statut = v_nouveau_statut,
         updated_at = now()
   WHERE facture_id = v_fac.facture_id;

  RETURN v_p;
END $function$;

GRANT EXECUTE ON FUNCTION public.enregistrer_paiement(jsonb) TO authenticated;

-- 3. View pratique pour récupérer les factures impayées d'un client
CREATE OR REPLACE FUNCTION public.factures_impayees_client(_client_id uuid)
 RETURNS TABLE(facture_id uuid, reference text, date_facture date, montant_total numeric, montant_paye numeric, solde numeric, statut text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT facture_id, reference, date_facture, montant_total, montant_paye,
         (COALESCE(montant_total,0) - COALESCE(montant_paye,0)) AS solde, statut
    FROM public.factures
   WHERE client_id = _client_id
     AND statut IN ('impayee','partielle')
   ORDER BY date_facture ASC
$function$;

GRANT EXECUTE ON FUNCTION public.factures_impayees_client(uuid) TO authenticated;
