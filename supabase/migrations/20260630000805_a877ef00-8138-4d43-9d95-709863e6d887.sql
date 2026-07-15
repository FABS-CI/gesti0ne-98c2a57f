
-- Retours : dépôt libre (obligatoire)
CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
 RETURNS retours
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r public.retours; l jsonb; v_qty int:=0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_qte int; v_actuel int;
BEGIN
  IF v_depot IS NULL THEN RAISE EXCEPTION 'Le dépôt est obligatoire pour un retour'; END IF;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;
  INSERT INTO public.retours(numero,date_retour,client_id,etablissement,representant_nom,telephone,ville,
    adresse,depot_id,observations,notes,statut,total_quantite,nb_produits,created_by,created_by_nom)
  VALUES('RET-'||to_char(now(),'YYYYMMDD-HH24MISS'),
    COALESCE((_payload->>'date_retour')::date,current_date),(_payload->>'client_id')::uuid,
    _payload->>'etablissement',_payload->>'representant_nom',_payload->>'telephone',_payload->>'ville',
    _payload->>'adresse',v_depot,_payload->>'observations',_payload->>'notes','accepte',v_qty,
    jsonb_array_length(COALESCE(_payload->'lignes','[]'::jsonb)),auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'))
  RETURNING * INTO r;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.retour_lignes(retour_id,produit_id,reference_produit,designation,quantite,motif)
    VALUES(r.retour_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',l->>'designation',
      COALESCE((l->>'quantite')::int,0),l->>'motif');
    IF l->>'produit_id' IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES((l->>'produit_id')::uuid,v_depot,0)
        ON CONFLICT(produit_id,depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id=(l->>'produit_id')::uuid AND depot_id=v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot((l->>'produit_id')::uuid,v_depot,v_actuel+v_qte,'Retour '||r.numero);
    END IF;
  END LOOP;
  RETURN r;
END $function$;

-- Spécimens : dépôt libre (obligatoire)
CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
 RETURNS specimens
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE s public.specimens; l jsonb; v_qty int:=0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_qte int; v_actuel int;
BEGIN
  IF v_depot IS NULL THEN RAISE EXCEPTION 'Le dépôt est obligatoire pour un spécimen'; END IF;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;
  INSERT INTO public.specimens(numero,date_envoi,date_remise,client_id,etablissement,representant_nom,
    telephone,ville,adresse,donneur_nom,motif,observations,statut,total_quantite,nb_produits,depot_id,
    created_by,gestionnaire_id,gestionnaire_nom)
  VALUES('SPC-'||to_char(now(),'YYYYMMDD-HH24MISS'),
    COALESCE((_payload->>'date_envoi')::date,current_date),
    COALESCE((_payload->>'date_envoi')::date,current_date),
    (_payload->>'client_id')::uuid,_payload->>'etablissement',_payload->>'representant_nom',
    _payload->>'telephone',_payload->>'ville',_payload->>'adresse',_payload->>'donneur_nom',
    _payload->>'motif',_payload->>'observations','enregistre',v_qty,
    jsonb_array_length(COALESCE(_payload->'lignes','[]'::jsonb)),v_depot,auth.uid(),auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'))
  RETURNING * INTO s;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.specimen_lignes(specimen_id,produit_id,reference_produit,designation,quantite,total_ligne)
    VALUES(s.specimen_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',
      l->>'designation',COALESCE((l->>'quantite')::int,0),0);
    IF l->>'produit_id' IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      SELECT COALESCE(quantite,0) INTO v_actuel FROM public.stocks_depots
        WHERE produit_id=(l->>'produit_id')::uuid AND depot_id=v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot((l->>'produit_id')::uuid,v_depot,
        GREATEST(COALESCE(v_actuel,0)-v_qte,0),'Spécimen '||s.numero);
    END IF;
  END LOOP;
  RETURN s;
END $function$;

-- Incidents : dépôt libre (obligatoire)
CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
 RETURNS incidents
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE i public.incidents; l jsonb; v_qty int:=0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_qte int; v_actuel int;
BEGIN
  IF v_depot IS NULL THEN RAISE EXCEPTION 'Le dépôt est obligatoire pour un incident'; END IF;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;
  INSERT INTO public.incidents(numero,type_incident,date_incident,depot_id,motif,observations,description,
    statut,total_quantite,nb_produits,responsable_id,responsable_nom)
  VALUES('INC-'||to_char(now(),'YYYYMMDD-HH24MISS'),_payload->>'type_incident',
    COALESCE((_payload->>'date_incident')::date,current_date),v_depot,_payload->>'motif',
    _payload->>'observations',_payload->>'motif','declare',v_qty,
    jsonb_array_length(COALESCE(_payload->'lignes','[]'::jsonb)),auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'))
  RETURNING * INTO i;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.incident_lignes(incident_id,produit_id,reference_produit,designation,quantite,impact_stock)
    VALUES(i.incident_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',
      l->>'designation',COALESCE((l->>'quantite')::int,0),-COALESCE((l->>'quantite')::int,0));
    IF l->>'produit_id' IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      SELECT COALESCE(quantite,0) INTO v_actuel FROM public.stocks_depots
        WHERE produit_id=(l->>'produit_id')::uuid AND depot_id=v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot((l->>'produit_id')::uuid,v_depot,
        GREATEST(COALESCE(v_actuel,0)-v_qte,0),'Incident '||i.reference);
    END IF;
  END LOOP;
  RETURN i;
END $function$;
