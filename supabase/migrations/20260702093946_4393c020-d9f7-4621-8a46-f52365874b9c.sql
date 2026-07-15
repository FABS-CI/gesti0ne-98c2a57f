-- Fix duplication : creer_commande appelait generer_proforma_commande alors qu'un trigger AFTER INSERT autocreate_proforma_for_commande le fait déjà, ce qui produisait 2 proformas par commande. On supprime l'appel explicite dans creer_commande.
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
  -- Proforma générée automatiquement par le trigger trg_autocreate_proforma
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd.commande_id;
  RETURN v_cmd;
END $function$;

-- Nettoyage : supprime les proformas orphelines (sans commande_id) créées en doublon
-- lorsque la commande liée possède déjà une proforma rattachée.
DELETE FROM public.proforma_lignes
WHERE proforma_id IN (
  SELECT p1.proforma_id FROM public.proformas p1
  WHERE p1.commande_id IS NULL
    AND p1.notes ILIKE 'Générée depuis commande %'
    AND EXISTS (
      SELECT 1 FROM public.proformas p2
      JOIN public.commandes c ON c.commande_id = p2.commande_id
      WHERE p2.commande_id IS NOT NULL
        AND p1.notes = 'Générée depuis commande ' || c.reference
    )
);
DELETE FROM public.proformas p1
WHERE p1.commande_id IS NULL
  AND p1.notes ILIKE 'Générée depuis commande %'
  AND EXISTS (
    SELECT 1 FROM public.proformas p2
    JOIN public.commandes c ON c.commande_id = p2.commande_id
    WHERE p2.commande_id IS NOT NULL
      AND p1.notes = 'Générée depuis commande ' || c.reference
  );

-- Sécurité : recopie les lignes de commande vers la proforma juste après création
-- (le trigger sync_proforma_lignes_from_commande fonctionne par ligne ; on garantit
-- ici la première synchro même si les lignes ont été insérées avant la proforma).
CREATE OR REPLACE FUNCTION public.autocreate_proforma_for_commande()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_existing uuid;
  v_new_id uuid;
BEGIN
  SELECT proforma_id INTO v_existing
  FROM public.proformas
  WHERE commande_id = NEW.commande_id
  LIMIT 1;

  IF v_existing IS NULL THEN
    INSERT INTO public.proformas (
      client_id, client_nom, commande_id, date_proforma,
      montant_total, statut, notes
    ) VALUES (
      NEW.client_id, NEW.client_nom, NEW.commande_id, COALESCE(NEW.date_commande, CURRENT_DATE),
      COALESCE(NEW.montant_total, 0), 'en_attente',
      'Proforma générée automatiquement depuis ' || NEW.reference
    ) RETURNING proforma_id INTO v_new_id;

    -- Recopie immédiate des lignes si elles existent déjà
    INSERT INTO public.proforma_lignes (proforma_id, produit_id, designation, quantite, prix_unitaire, total_ligne)
    SELECT v_new_id, produit_id, designation, quantite, prix_unitaire, COALESCE(total_ht_ligne, total_ligne)
    FROM public.commande_lignes
    WHERE commande_id = NEW.commande_id;
  END IF;

  RETURN NEW;
END;
$function$;