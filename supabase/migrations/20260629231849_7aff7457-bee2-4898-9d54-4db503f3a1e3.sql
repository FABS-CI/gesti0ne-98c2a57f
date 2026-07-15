
-- Trigger cassé : stock_mouvements n'a pas de updated_at
DROP TRIGGER IF EXISTS update_stock_mouvements_updated_at ON public.stock_mouvements;

-- 1. Dépôt principal (backfill)
DO $$
DECLARE v_principal uuid;
BEGIN
  SELECT depot_id INTO v_principal FROM public.depots WHERE is_principal = true LIMIT 1;
  IF v_principal IS NULL THEN
    INSERT INTO public.depots(code, nom, type_depot, is_principal, actif)
    VALUES ('DEP-PRINCIPAL', 'Dépôt Principal', 'principal', true, true)
    RETURNING depot_id INTO v_principal;
  END IF;
END $$;

-- 2. depot_id sur achats / commandes
ALTER TABLE public.achats    ADD COLUMN IF NOT EXISTS depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL;
ALTER TABLE public.commandes ADD COLUMN IF NOT EXISTS depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL;
ALTER TABLE public.specimens ADD COLUMN IF NOT EXISTS depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL;

UPDATE public.achats          SET depot_id=(SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1) WHERE depot_id IS NULL;
UPDATE public.commandes       SET depot_id=(SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1) WHERE depot_id IS NULL;
UPDATE public.specimens       SET depot_id=(SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1) WHERE depot_id IS NULL;
UPDATE public.retours         SET depot_id=(SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1) WHERE depot_id IS NULL;
UPDATE public.incidents       SET depot_id=(SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1) WHERE depot_id IS NULL;
UPDATE public.inventaires     SET depot_id=(SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1) WHERE depot_id IS NULL AND type_inventaire <> 'global';
UPDATE public.stock_mouvements SET depot_id=(SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1) WHERE depot_id IS NULL;

-- 3. Quantités négatives interdites
ALTER TABLE public.stocks_depots DROP CONSTRAINT IF EXISTS stocks_depots_quantite_check;
ALTER TABLE public.stocks_depots ADD  CONSTRAINT stocks_depots_quantite_check CHECK (quantite >= 0);

-- 4. Paramètre "dépôt par défaut"
INSERT INTO public.parametres(cle, valeur, description)
SELECT 'depot_defaut_id',
       (SELECT depot_id::text FROM public.depots WHERE is_principal LIMIT 1),
       'UUID du dépôt proposé par défaut sur ventes, commandes et approvisionnements'
ON CONFLICT (cle) DO NOTHING;

-- 5. produits.stock = SUM(stocks_depots.quantite) via trigger
CREATE OR REPLACE FUNCTION public.refresh_produit_stock(_produit_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.produits
     SET stock = COALESCE((SELECT SUM(quantite) FROM public.stocks_depots WHERE produit_id = _produit_id), 0),
         updated_at = now()
   WHERE produit_id = _produit_id;
END $$;

CREATE OR REPLACE FUNCTION public.trg_stocks_depots_refresh()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.refresh_produit_stock(OLD.produit_id);
  ELSE
    PERFORM public.refresh_produit_stock(NEW.produit_id);
    IF TG_OP = 'UPDATE' AND OLD.produit_id <> NEW.produit_id THEN
      PERFORM public.refresh_produit_stock(OLD.produit_id);
    END IF;
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_stocks_depots_refresh ON public.stocks_depots;
CREATE TRIGGER trg_stocks_depots_refresh
  AFTER INSERT OR UPDATE OR DELETE ON public.stocks_depots
  FOR EACH ROW EXECUTE FUNCTION public.trg_stocks_depots_refresh();

-- 6. apply_stock_mouvement → ne touche plus produits.stock
CREATE OR REPLACE FUNCTION public.apply_stock_mouvement()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  NEW.stock_resultant := COALESCE((SELECT stock FROM public.produits WHERE produit_id = NEW.produit_id), 0);
  RETURN NEW;
END $$;

-- 7. Resync global
UPDATE public.produits p
   SET stock = COALESCE((SELECT SUM(quantite) FROM public.stocks_depots WHERE produit_id = p.produit_id), 0);

-- 8. enregistrer_approvisionnement (dépôt obligatoire)
CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
RETURNS achats LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE a public.achats; l jsonb; v_total numeric:=0; v_qty int:=0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_qte int; v_actuel int;
BEGIN
  IF v_depot IS NULL THEN RAISE EXCEPTION 'Le dépôt est obligatoire pour un approvisionnement'; END IF;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_total := v_total + (COALESCE((l->>'quantite')::int,0)*COALESCE((l->>'prix_unitaire')::numeric,0));
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;
  INSERT INTO public.achats(fournisseur_id,fournisseur_nom,libelle,montant,statut,date_achat,
    reference_fournisseur,notes,total_quantite,depot_id,created_by,created_by_nom)
  SELECT (_payload->>'fournisseur_id')::uuid,f.raison_sociale,'Approvisionnement',v_total,'recu',
    COALESCE((_payload->>'date_achat')::date,current_date),_payload->>'reference_fournisseur',
    _payload->>'notes',v_qty,v_depot,auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email')
  FROM public.fournisseurs f WHERE f.fournisseur_id=(_payload->>'fournisseur_id')::uuid
  RETURNING * INTO a;
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.achat_lignes(achat_id,produit_id,reference_produit,designation,quantite,prix_unitaire,total_ligne)
    VALUES(a.achat_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',l->>'designation',
      COALESCE((l->>'quantite')::int,0),COALESCE((l->>'prix_unitaire')::numeric,0),
      COALESCE((l->>'quantite')::int,0)*COALESCE((l->>'prix_unitaire')::numeric,0));
    IF l->>'produit_id' IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES((l->>'produit_id')::uuid,v_depot,0)
        ON CONFLICT(produit_id,depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id=(l->>'produit_id')::uuid AND depot_id=v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot((l->>'produit_id')::uuid,v_depot,v_actuel+v_qte,'Approvisionnement '||a.reference);
    END IF;
  END LOOP;
  RETURN a;
END $$;

-- 9. creer_retour (dépôt obligatoire)
CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
RETURNS retours LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
END $$;

-- 10. creer_specimen (dépôt obligatoire)
CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
RETURNS specimens LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
END $$;

-- 11. creer_incident_stock (dépôt obligatoire)
CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
RETURNS incidents LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
END $$;

-- 12. creer_commande (depot_id supporté)
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
RETURNS commandes LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cmd public.commandes; v_l jsonb; v_client record; v_nom text;
  v_depot uuid := COALESCE(NULLIF(_payload->>'depot_id','')::uuid,
                           (SELECT NULLIF(valeur,'')::uuid FROM public.parametres WHERE cle='depot_defaut_id'),
                           (SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1));
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
END $$;

CREATE OR REPLACE FUNCTION public.modifier_commande(_commande_id uuid, _payload jsonb)
RETURNS commandes LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cmd public.commandes; v_l jsonb;
BEGIN
  UPDATE public.commandes SET
    date_commande=COALESCE((_payload->>'date_commande')::date,date_commande),
    etablissement=COALESCE(_payload->>'etablissement',etablissement),
    representant_nom=COALESCE(_payload->>'representant_nom',representant_nom),
    telephone=COALESCE(_payload->>'telephone',telephone),
    ville=COALESCE(_payload->>'ville',ville),
    adresse=COALESCE(_payload->>'adresse',adresse),
    observations=COALESCE(_payload->>'observations',observations),
    remise_globale_pct=COALESCE((_payload->>'remise_globale_pct')::numeric,remise_globale_pct),
    taux_tva=COALESCE((_payload->>'taux_tva')::numeric,taux_tva),
    depot_id=COALESCE(NULLIF(_payload->>'depot_id','')::uuid,depot_id),
    updated_at=now()
  WHERE commande_id=_commande_id RETURNING * INTO v_cmd;
  IF _payload ? 'lignes' THEN
    DELETE FROM public.commande_lignes WHERE commande_id=_commande_id;
    FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
      INSERT INTO public.commande_lignes(commande_id,produit_id,reference_produit,designation,
        quantite,prix_unitaire,remise_pct,montant_remise,total_ht_ligne,total_ligne)
      VALUES(_commande_id,NULLIF(v_l->>'produit_id','')::uuid,v_l->>'reference_produit',
        v_l->>'designation',COALESCE((v_l->>'quantite')::int,1),
        COALESCE((v_l->>'prix_unitaire')::numeric,0),COALESCE((v_l->>'remise_pct')::numeric,0),
        (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*COALESCE((v_l->>'remise_pct')::numeric,0)/100),
        (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*(1-COALESCE((v_l->>'remise_pct')::numeric,0)/100)),
        (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*(1-COALESCE((v_l->>'remise_pct')::numeric,0)/100)));
    END LOOP;
  END IF;
  PERFORM public.recalc_commande(_commande_id);
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=_commande_id; RETURN v_cmd;
END $$;

CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
RETURNS TABLE(facture_reference text, bl_reference text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c record; f_ref text; b_ref text; l record;
  v_depot uuid; v_actuel int;
BEGIN
  SELECT * INTO c FROM public.commandes WHERE commande_id=_commande_id;
  v_depot := COALESCE(c.depot_id,
                      (SELECT NULLIF(valeur,'')::uuid FROM public.parametres WHERE cle='depot_defaut_id'),
                      (SELECT depot_id FROM public.depots WHERE is_principal LIMIT 1));
  IF v_depot IS NULL THEN RAISE EXCEPTION 'Dépôt manquant pour la commande'; END IF;
  FOR l IN SELECT produit_id,quantite FROM public.commande_lignes
            WHERE commande_id=_commande_id AND produit_id IS NOT NULL LOOP
    INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES(l.produit_id,v_depot,0)
      ON CONFLICT(produit_id,depot_id) DO NOTHING;
    SELECT COALESCE(quantite,0) INTO v_actuel FROM public.stocks_depots
      WHERE produit_id=l.produit_id AND depot_id=v_depot FOR UPDATE;
    PERFORM public.ajuster_stock_depot(l.produit_id,v_depot,GREATEST(v_actuel-l.quantite,0),'Vente commande '||c.reference);
  END LOOP;
  UPDATE public.commandes SET statut='validee',updated_at=now() WHERE commande_id=_commande_id;
  INSERT INTO public.factures(client_id,client_nom,commande_id,montant_total,montant_paye,statut,notes)
    VALUES(c.client_id,c.client_nom,_commande_id,c.montant_total,0,'impayee','Facturation de la commande '||c.reference)
    RETURNING reference INTO f_ref;
  INSERT INTO public.bons_livraison(commande_id,client_id,montant_total,statut,adresse_livraison)
    VALUES(_commande_id,c.client_id,c.montant_total,'brouillon',c.adresse)
    RETURNING reference INTO b_ref;
  facture_reference:=f_ref; bl_reference:=b_ref; RETURN NEXT;
END $$;

-- 13. Inventaire théorique et global
CREATE OR REPLACE FUNCTION public.creer_inventaire_theorique(_payload jsonb)
RETURNS inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv public.inventaires;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
BEGIN
  IF v_depot IS NULL THEN RAISE EXCEPTION 'Le dépôt est obligatoire pour un inventaire théorique'; END IF;
  INSERT INTO public.inventaires(numero,reference,type_inventaire,depot_id,date_inventaire,statut,
    observations,created_by,created_by_nom)
  VALUES('INV-T-'||to_char(now(),'YYYYMMDD-HH24MISS'),
    'INV-T-'||to_char(now(),'YYYYMMDD-HH24MISS'),'theorique',v_depot,
    COALESCE((_payload->>'date_inventaire')::date,current_date),'valide',_payload->>'observations',
    auth.uid(),COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'))
  RETURNING * INTO inv;
  INSERT INTO public.inventaire_lignes(inventaire_id,produit_id,reference_produit,designation,
    stock_theorique,quantite_comptee,ecart,valeur_unitaire,valeur_ecart)
  SELECT inv.inventaire_id,pr.produit_id,pr.reference,pr.titre,
    COALESCE(sd.quantite,0),COALESCE(sd.quantite,0),0,COALESCE(pr.prix_achat,0),0
  FROM public.produits pr
  LEFT JOIN public.stocks_depots sd ON sd.produit_id=pr.produit_id AND sd.depot_id=v_depot
  WHERE pr.actif;
  UPDATE public.inventaires SET
    nb_produits=(SELECT COUNT(*) FROM public.inventaire_lignes WHERE inventaire_id=inv.inventaire_id),
    valeur_totale=(SELECT COALESCE(SUM(stock_theorique*valeur_unitaire),0) FROM public.inventaire_lignes WHERE inventaire_id=inv.inventaire_id),
    validated_at=now()
  WHERE inventaire_id=inv.inventaire_id RETURNING * INTO inv;
  RETURN inv;
END $$;

CREATE OR REPLACE FUNCTION public.creer_inventaire_global(_payload jsonb DEFAULT '{}'::jsonb)
RETURNS inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv public.inventaires;
BEGIN
  INSERT INTO public.inventaires(numero,reference,type_inventaire,depot_id,date_inventaire,statut,
    observations,created_by,created_by_nom)
  VALUES('INV-G-'||to_char(now(),'YYYYMMDD-HH24MISS'),
    'INV-G-'||to_char(now(),'YYYYMMDD-HH24MISS'),'global',NULL,
    COALESCE((_payload->>'date_inventaire')::date,current_date),'valide',_payload->>'observations',
    auth.uid(),COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'))
  RETURNING * INTO inv;
  INSERT INTO public.inventaire_lignes(inventaire_id,produit_id,reference_produit,designation,
    stock_theorique,quantite_comptee,ecart,valeur_unitaire,valeur_ecart,observation)
  SELECT inv.inventaire_id,pr.produit_id,pr.reference,pr.titre,
    sd.quantite,sd.quantite,0,COALESCE(pr.prix_achat,0),0,d.nom
  FROM public.stocks_depots sd
  JOIN public.depots d ON d.depot_id=sd.depot_id AND d.actif
  JOIN public.produits pr ON pr.produit_id=sd.produit_id AND pr.actif
  WHERE sd.quantite > 0;
  UPDATE public.inventaires SET
    nb_produits=(SELECT COUNT(*) FROM public.inventaire_lignes WHERE inventaire_id=inv.inventaire_id),
    valeur_totale=(SELECT COALESCE(SUM(stock_theorique*valeur_unitaire),0) FROM public.inventaire_lignes WHERE inventaire_id=inv.inventaire_id),
    validated_at=now()
  WHERE inventaire_id=inv.inventaire_id RETURNING * INTO inv;
  RETURN inv;
END $$;
