
-- 1. Helper: can_choose_depot
CREATE OR REPLACE FUNCTION public.can_choose_depot(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_any_role(_user_id, ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[])
$$;

-- 2. Single principal: unique partial index + trigger
CREATE UNIQUE INDEX IF NOT EXISTS depots_unique_principal_idx
  ON public.depots (is_principal) WHERE is_principal = true;

CREATE OR REPLACE FUNCTION public.trg_depots_principal_unique()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_principal IS TRUE THEN
    UPDATE public.depots SET is_principal = false, type_depot = 'secondaire', updated_at = now()
      WHERE depot_id <> NEW.depot_id AND is_principal = true;
    NEW.type_depot := 'principal';
  ELSE
    IF NEW.type_depot = 'principal' THEN NEW.type_depot := 'secondaire'; END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_depots_principal_unique ON public.depots;
CREATE TRIGGER trg_depots_principal_unique
  BEFORE INSERT OR UPDATE OF is_principal ON public.depots
  FOR EACH ROW EXECUTE FUNCTION public.trg_depots_principal_unique();

-- 3. RPC to promote a depot
CREATE OR REPLACE FUNCTION public.definir_depot_principal(_depot_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','gestionnaire_stock']::app_role[]) THEN
    RAISE EXCEPTION 'Non autorisé à définir le dépôt principal';
  END IF;
  UPDATE public.depots SET is_principal = false, type_depot = 'secondaire', updated_at = now()
    WHERE is_principal = true AND depot_id <> _depot_id;
  UPDATE public.depots SET is_principal = true, type_depot = 'principal', actif = true, updated_at = now()
    WHERE depot_id = _depot_id;
END $$;

-- 4. Helper: resolve depot for stock exit (principal first)
CREATE OR REPLACE FUNCTION public.resolve_depot_sortie(_requested uuid, _module text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_principal uuid;
  v_resolved uuid;
  v_override boolean := false;
BEGIN
  SELECT depot_id INTO v_principal FROM public.depots WHERE is_principal AND actif LIMIT 1;
  IF v_principal IS NULL THEN
    SELECT NULLIF(valeur,'')::uuid INTO v_principal FROM public.parametres WHERE cle='depot_defaut_id';
  END IF;
  IF v_principal IS NULL THEN
    SELECT depot_id INTO v_principal FROM public.depots WHERE actif ORDER BY created_at LIMIT 1;
  END IF;

  IF _requested IS NULL OR _requested = v_principal THEN
    v_resolved := v_principal;
  ELSE
    IF public.can_choose_depot(auth.uid()) THEN
      v_resolved := _requested;
      v_override := true;
    ELSE
      RAISE EXCEPTION 'Déstockage hors dépôt principal non autorisé pour ce profil';
    END IF;
  END IF;

  IF v_override THEN
    INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, new_values)
    VALUES(auth.uid(), COALESCE(auth.jwt()->>'email',''), 'stock_exit_override', _module, v_resolved::text,
      jsonb_build_object('depot_principal_id', v_principal, 'depot_utilise_id', v_resolved, 'module', _module));
  END IF;

  IF v_resolved IS NULL THEN RAISE EXCEPTION 'Aucun dépôt disponible pour la sortie de stock'; END IF;
  RETURN v_resolved;
END $$;

-- 5. Rewrite RPCs that perform stock exits to force principal (override-able)
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
RETURNS commandes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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
    'brouillon','CMD-'||to_char(now(),'YYYYMMDD-HH24MISS')) RETURNING * INTO v_cmd;
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
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd.commande_id;
  RETURN v_cmd;
END $function$;

CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
RETURNS TABLE(facture_reference text, bl_reference text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE c record; f_ref text; b_ref text; l record;
  v_depot uuid; v_actuel int;
BEGIN
  SELECT * INTO c FROM public.commandes WHERE commande_id=_commande_id;
  v_depot := public.resolve_depot_sortie(c.depot_id, 'commandes');
  FOR l IN SELECT produit_id,quantite FROM public.commande_lignes
            WHERE commande_id=_commande_id AND produit_id IS NOT NULL LOOP
    INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES(l.produit_id,v_depot,0)
      ON CONFLICT(produit_id,depot_id) DO NOTHING;
    SELECT COALESCE(quantite,0) INTO v_actuel FROM public.stocks_depots
      WHERE produit_id=l.produit_id AND depot_id=v_depot FOR UPDATE;
    PERFORM public.ajuster_stock_depot(l.produit_id,v_depot,GREATEST(v_actuel-l.quantite,0),'Vente commande '||c.reference);
  END LOOP;
  UPDATE public.commandes SET statut='validee',depot_id=v_depot,updated_at=now() WHERE commande_id=_commande_id;
  INSERT INTO public.factures(client_id,client_nom,commande_id,montant_total,montant_paye,statut,notes)
    VALUES(c.client_id,c.client_nom,_commande_id,c.montant_total,0,'impayee','Facturation de la commande '||c.reference)
    RETURNING reference INTO f_ref;
  INSERT INTO public.bons_livraison(commande_id,client_id,montant_total,statut,adresse_livraison)
    VALUES(_commande_id,c.client_id,c.montant_total,'brouillon',c.adresse)
    RETURNING reference INTO b_ref;
  facture_reference:=f_ref; bl_reference:=b_ref; RETURN NEXT;
END $function$;

CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
RETURNS specimens
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE s public.specimens; l jsonb; v_qty int:=0;
  v_depot uuid := public.resolve_depot_sortie(NULLIF(_payload->>'depot_id','')::uuid, 'specimens');
  v_qte int; v_actuel int;
BEGIN
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

CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
RETURNS retours
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE r public.retours; l jsonb; v_qty int:=0;
  v_depot uuid := public.resolve_depot_sortie(NULLIF(_payload->>'depot_id','')::uuid, 'retours');
  v_qte int; v_actuel int;
BEGIN
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

CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
RETURNS incidents
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE i public.incidents; l jsonb; v_qty int:=0;
  v_depot uuid := public.resolve_depot_sortie(NULLIF(_payload->>'depot_id','')::uuid, 'incidents');
  v_qte int; v_actuel int;
BEGIN
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

-- 6. Trigger: alerte de seuil sur le dépôt principal
CREATE OR REPLACE FUNCTION public.trg_alerte_seuil_principal()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_principal boolean; v_seuil int; v_titre text; v_ref text;
BEGIN
  SELECT is_principal INTO v_principal FROM public.depots WHERE depot_id = NEW.depot_id;
  IF NOT COALESCE(v_principal,false) THEN RETURN NEW; END IF;
  SELECT COALESCE(NULLIF(p.seuil_alerte,0), 0), p.reference INTO v_seuil, v_ref
    FROM public.produits p WHERE p.produit_id = NEW.produit_id;
  IF v_seuil <= 0 THEN RETURN NEW; END IF;
  IF NEW.quantite <= v_seuil AND COALESCE(OLD.quantite, NEW.quantite + 1) > v_seuil THEN
    v_titre := 'Seuil dépôt principal atteint';
    INSERT INTO public.notifications(titre, message, type_notification, lu, date_notification)
    VALUES(v_titre,
      'Le produit '||COALESCE(v_ref,'')||' est à '||NEW.quantite||' (seuil '||v_seuil||') dans le dépôt principal. Pensez à organiser un transfert depuis un dépôt secondaire.',
      'alerte_stock', false, current_date);
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_alerte_seuil_principal ON public.stocks_depots;
CREATE TRIGGER trg_alerte_seuil_principal
  AFTER INSERT OR UPDATE OF quantite ON public.stocks_depots
  FOR EACH ROW EXECUTE FUNCTION public.trg_alerte_seuil_principal();
