
-- 1) Étendre stock_mouvements
ALTER TABLE public.stock_mouvements
  ADD COLUMN IF NOT EXISTS origine text,
  ADD COLUMN IF NOT EXISTS document_id uuid,
  ADD COLUMN IF NOT EXISTS document_reference text,
  ADD COLUMN IF NOT EXISTS document_table text,
  ADD COLUMN IF NOT EXISTS user_id uuid,
  ADD COLUMN IF NOT EXISTS user_nom text,
  ADD COLUMN IF NOT EXISTS observation text,
  ADD COLUMN IF NOT EXISTS quantite_entree integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quantite_sortie integer DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_stock_mouvements_produit_date
  ON public.stock_mouvements(produit_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_mouvements_depot
  ON public.stock_mouvements(depot_id);
CREATE INDEX IF NOT EXISTS idx_stock_mouvements_origine
  ON public.stock_mouvements(origine);

-- 2) Rendre apply_stock_mouvement no-op (on remplit déjà stock_resultant et entree/sortie depuis ajuster_stock_depot)
CREATE OR REPLACE FUNCTION public.apply_stock_mouvement()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.stock_resultant IS NULL OR NEW.stock_resultant = 0 THEN
    NEW.stock_resultant := COALESCE((SELECT stock FROM public.produits WHERE produit_id = NEW.produit_id), 0);
  END IF;
  RETURN NEW;
END $function$;

-- 3) Nouvelle signature de ajuster_stock_depot avec traçabilité
CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(
  _produit_id uuid,
  _depot_id uuid,
  _nouvelle_quantite integer,
  _motif text DEFAULT NULL,
  _origine text DEFAULT 'ajustement',
  _document_id uuid DEFAULT NULL,
  _document_reference text DEFAULT NULL,
  _document_table text DEFAULT NULL,
  _observation text DEFAULT NULL
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_current integer;
  v_delta integer;
  v_entree integer := 0;
  v_sortie integer := 0;
  v_type text;
  v_stock_total integer;
  v_user_nom text;
BEGIN
  INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
    VALUES(_produit_id, _depot_id, 0)
    ON CONFLICT(produit_id, depot_id) DO NOTHING;

  SELECT quantite INTO v_current FROM public.stocks_depots
    WHERE produit_id = _produit_id AND depot_id = _depot_id FOR UPDATE;

  v_delta := _nouvelle_quantite - COALESCE(v_current, 0);

  UPDATE public.stocks_depots
    SET quantite = _nouvelle_quantite, updated_at = now()
    WHERE produit_id = _produit_id AND depot_id = _depot_id;

  UPDATE public.produits
    SET stock = (SELECT COALESCE(SUM(quantite),0) FROM public.stocks_depots WHERE produit_id = _produit_id),
        updated_at = now()
    WHERE produit_id = _produit_id
    RETURNING stock INTO v_stock_total;

  IF v_delta > 0 THEN
    v_entree := v_delta; v_type := 'entree';
  ELSIF v_delta < 0 THEN
    v_sortie := -v_delta; v_type := 'sortie';
  ELSE
    v_type := 'ajustement';
  END IF;

  v_user_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  INSERT INTO public.stock_mouvements(
    produit_id, depot_id, type, quantite, stock_resultant, motif,
    origine, document_id, document_reference, document_table,
    user_id, user_nom, observation, quantite_entree, quantite_sortie
  ) VALUES(
    _produit_id, _depot_id, v_type, ABS(v_delta), v_stock_total, _motif,
    COALESCE(_origine, 'ajustement'), _document_id, _document_reference, _document_table,
    auth.uid(), v_user_nom, _observation, v_entree, v_sortie
  );
END $function$;

-- 4) RPC métiers : passer l'origine et la référence
CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
 RETURNS TABLE(facture_reference text, bl_reference text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
    PERFORM public.ajuster_stock_depot(
      l.produit_id, v_depot, GREATEST(v_actuel-l.quantite,0),
      'Vente commande '||c.reference,
      'commande', _commande_id, c.reference, 'commandes', NULL
    );
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

CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
 RETURNS achats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot, v_actuel+v_qte,
        'Approvisionnement '||a.reference,
        'approvisionnement', a.achat_id, a.reference, 'achats', NULL
      );
    END IF;
  END LOOP;
  RETURN a;
END $function$;

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
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot, v_actuel+v_qte,
        'Retour '||r.numero,
        'retour', r.retour_id, r.numero, 'retours', l->>'motif'
      );
    END IF;
  END LOOP;
  RETURN r;
END $function$;

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
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot,
        GREATEST(COALESCE(v_actuel,0)-v_qte,0),
        'Spécimen '||s.numero,
        'specimen', s.specimen_id, s.numero, 'specimens', NULL
      );
    END IF;
  END LOOP;
  RETURN s;
END $function$;

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
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot,
        GREATEST(COALESCE(v_actuel,0)-v_qte,0),
        'Incident '||COALESCE(i.reference,i.numero),
        'incident', i.incident_id, COALESCE(i.reference,i.numero), 'incidents', _payload->>'motif'
      );
    END IF;
  END LOOP;
  RETURN i;
END $function$;

CREATE OR REPLACE FUNCTION public.executer_transfert(_transfert_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE t record; l record;
BEGIN
  SELECT * INTO t FROM public.transferts WHERE transfert_id=_transfert_id FOR UPDATE;
  FOR l IN SELECT * FROM public.transfert_lignes WHERE transfert_id=_transfert_id LOOP
    PERFORM public.ajuster_stock_depot(
      l.produit_id, t.depot_source_id,
      GREATEST((SELECT COALESCE(quantite,0) FROM public.stocks_depots
        WHERE produit_id=l.produit_id AND depot_id=t.depot_source_id)-l.quantite,0),
      'Transfert '||t.numero,
      'transfert_sortant', t.transfert_id, t.numero, 'transferts', NULL
    );
    PERFORM public.ajuster_stock_depot(
      l.produit_id, t.depot_destination_id,
      (SELECT COALESCE(quantite,0) FROM public.stocks_depots
        WHERE produit_id=l.produit_id AND depot_id=t.depot_destination_id)+l.quantite,
      'Transfert '||t.numero,
      'transfert_entrant', t.transfert_id, t.numero, 'transferts', NULL
    );
  END LOOP;
  UPDATE public.transferts SET statut='expedie',date_expedition=now(),updated_at=now() WHERE transfert_id=_transfert_id;
END $function$;

CREATE OR REPLACE FUNCTION public.regulariser_inventaire(_inventaire_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE inv record; l record;
BEGIN
  SELECT * INTO inv FROM public.inventaires WHERE inventaire_id=_inventaire_id;
  FOR l IN SELECT * FROM public.inventaire_lignes
            WHERE inventaire_id=_inventaire_id AND quantite_comptee IS NOT NULL LOOP
    PERFORM public.ajuster_stock_depot(
      l.produit_id, inv.depot_id, l.quantite_comptee,
      'Régularisation inventaire '||inv.numero,
      'inventaire', inv.inventaire_id, inv.numero, 'inventaires', l.observation
    );
  END LOOP;
  UPDATE public.inventaires SET statut='regularise',regularized_at=now(),updated_at=now() WHERE inventaire_id=_inventaire_id;
END $function$;
