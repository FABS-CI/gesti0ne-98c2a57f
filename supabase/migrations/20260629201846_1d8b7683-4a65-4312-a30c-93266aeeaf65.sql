-- Complement FABS-CI ERP schema to match application code
ALTER TABLE public.achats
  ADD COLUMN IF NOT EXISTS reference_fournisseur text;
ALTER TABLE public.achat_lignes
  ADD COLUMN IF NOT EXISTS reference_produit text,
  ALTER COLUMN produit_id DROP NOT NULL;

ALTER TABLE public.commandes
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS etablissement text,
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS nb_produits integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_quantite integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ht_brut numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_remises_lignes numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ht_net numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remise_globale_pct numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remise_globale_montant numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS taux_tva numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_tva numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_ttc numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_a_payer numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS commercial_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS commercial_nom text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by_nom text;
ALTER TABLE public.commande_lignes
  ADD COLUMN IF NOT EXISTS reference_produit text,
  ADD COLUMN IF NOT EXISTS remise_pct numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_remise numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ht_ligne numeric NOT NULL DEFAULT 0;

ALTER TABLE public.depots
  ADD COLUMN IF NOT EXISTS type_depot text NOT NULL DEFAULT 'secondaire',
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS pays text DEFAULT 'Côte d''Ivoire',
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS commune text,
  ADD COLUMN IF NOT EXISTS quartier text,
  ADD COLUMN IF NOT EXISTS code_postal text,
  ADD COLUMN IF NOT EXISTS latitude numeric,
  ADD COLUMN IF NOT EXISTS longitude numeric,
  ADD COLUMN IF NOT EXISTS responsable_email text,
  ADD COLUMN IF NOT EXISTS capacite integer;

ALTER TABLE public.document_settings
  ADD COLUMN IF NOT EXISTS selected_template text NOT NULL DEFAULT 'classique',
  ADD COLUMN IF NOT EXISTS template_per_type jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS logo_url text;

ALTER TABLE public.specimens
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS date_envoi date NOT NULL DEFAULT current_date,
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS donneur_nom text,
  ADD COLUMN IF NOT EXISTS nb_produits integer NOT NULL DEFAULT 0;
ALTER TABLE public.specimens DROP CONSTRAINT IF EXISTS specimens_statut_chk;
ALTER TABLE public.specimens ADD CONSTRAINT specimens_statut_chk CHECK (statut IN ('brouillon','validee','annulee','enregistre','annule'));
ALTER TABLE public.specimen_lignes ALTER COLUMN produit_id DROP NOT NULL;

ALTER TABLE public.retours
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS etablissement text,
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS nb_produits integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by_nom text;
ALTER TABLE public.retour_lignes
  ADD COLUMN IF NOT EXISTS reference_produit text,
  ADD COLUMN IF NOT EXISTS motif text;

ALTER TABLE public.incidents
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS motif text,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS responsable_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS responsable_nom text,
  ADD COLUMN IF NOT EXISTS total_quantite integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_produits integer NOT NULL DEFAULT 0;
ALTER TABLE public.incident_lignes
  ADD COLUMN IF NOT EXISTS reference_produit text;

ALTER TABLE public.inventaires
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS categorie_id uuid REFERENCES public.categories_produits(categorie_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS nb_ecarts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valeur_totale numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by_nom text,
  ADD COLUMN IF NOT EXISTS validated_at timestamptz,
  ADD COLUMN IF NOT EXISTS regularized_at timestamptz;
ALTER TABLE public.inventaires DROP CONSTRAINT IF EXISTS inventaires_type_inventaire_check;
ALTER TABLE public.inventaires DROP CONSTRAINT IF EXISTS inventaires_statut_check;
ALTER TABLE public.inventaires ADD CONSTRAINT inventaires_type_inventaire_check CHECK (type_inventaire IN ('general','tournant','controle','physique','theorique','global','par_depot'));
ALTER TABLE public.inventaires ADD CONSTRAINT inventaires_statut_check CHECK (statut IN ('brouillon','en_cours','valide','regularise','annule'));
ALTER TABLE public.inventaire_lignes
  ADD COLUMN IF NOT EXISTS quantite_comptee integer,
  ADD COLUMN IF NOT EXISTS valeur_unitaire numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valeur_ecart numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS observation text;

CREATE OR REPLACE FUNCTION public.recalc_commande(_commande_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v record;
BEGIN
  SELECT count(*)::int nb, coalesce(sum(quantite),0)::int qty,
         coalesce(sum(quantite*prix_unitaire),0) brut,
         coalesce(sum(coalesce(montant_remise,0)),0) rem_lignes,
         coalesce(sum(coalesce(total_ht_ligne,total_ligne,quantite*prix_unitaire)),0) ht_lignes
    INTO v
  FROM public.commande_lignes WHERE commande_id=_commande_id;
  UPDATE public.commandes c SET
    nb_produits=coalesce(v.nb,0), total_quantite=coalesce(v.qty,0), total_ht_brut=coalesce(v.brut,0),
    total_remises_lignes=coalesce(v.rem_lignes,0), total_ht_net=greatest(coalesce(v.ht_lignes,0)-coalesce(c.remise_globale_montant,0),0),
    montant_tva=greatest(coalesce(v.ht_lignes,0)-coalesce(c.remise_globale_montant,0),0)*coalesce(c.taux_tva,0)/100,
    montant_ttc=greatest(coalesce(v.ht_lignes,0)-coalesce(c.remise_globale_montant,0),0)*(1+coalesce(c.taux_tva,0)/100),
    net_a_payer=greatest(coalesce(v.ht_lignes,0)-coalesce(c.remise_globale_montant,0),0)*(1+coalesce(c.taux_tva,0)/100),
    montant_total=greatest(coalesce(v.ht_lignes,0)-coalesce(c.remise_globale_montant,0),0)*(1+coalesce(c.taux_tva,0)/100),
    updated_at=now()
  WHERE c.commande_id=_commande_id;
END $$;

CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
RETURNS public.commandes LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_cmd public.commandes; v_l jsonb; v_client record; v_nom text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  SELECT * INTO v_client FROM public.clients WHERE client_id=(_payload->>'client_id')::uuid;
  v_nom := coalesce(v_client.nom, _payload->>'client_nom');
  INSERT INTO public.commandes(client_id,client_nom,etablissement,representant_nom,telephone,ville,adresse,observations,date_commande,remise_globale_pct,taux_tva,created_by,created_by_nom,statut,numero)
  VALUES((_payload->>'client_id')::uuid,v_nom,_payload->>'etablissement',_payload->>'representant_nom',_payload->>'telephone',_payload->>'ville',_payload->>'adresse',_payload->>'observations',coalesce((_payload->>'date_commande')::date,current_date),coalesce((_payload->>'remise_globale_pct')::numeric,0),coalesce((_payload->>'taux_tva')::numeric,0),auth.uid(),coalesce(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'),'brouillon','CMD-'||to_char(now(),'YYYYMMDD-HH24MISS')) RETURNING * INTO v_cmd;
  FOR v_l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.commande_lignes(commande_id,produit_id,reference_produit,designation,quantite,prix_unitaire,remise_pct,montant_remise,total_ht_ligne,total_ligne)
    VALUES(v_cmd.commande_id,NULLIF(v_l->>'produit_id','')::uuid,v_l->>'reference_produit',v_l->>'designation',coalesce((v_l->>'quantite')::int,1),coalesce((v_l->>'prix_unitaire')::numeric,0),coalesce((v_l->>'remise_pct')::numeric,0),(coalesce((v_l->>'quantite')::int,1)*coalesce((v_l->>'prix_unitaire')::numeric,0)*coalesce((v_l->>'remise_pct')::numeric,0)/100),(coalesce((v_l->>'quantite')::int,1)*coalesce((v_l->>'prix_unitaire')::numeric,0)*(1-coalesce((v_l->>'remise_pct')::numeric,0)/100)),(coalesce((v_l->>'quantite')::int,1)*coalesce((v_l->>'prix_unitaire')::numeric,0)*(1-coalesce((v_l->>'remise_pct')::numeric,0)/100)));
  END LOOP;
  PERFORM public.recalc_commande(v_cmd.commande_id);
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd.commande_id;
  RETURN v_cmd;
END $$;

CREATE OR REPLACE FUNCTION public.modifier_commande(_commande_id uuid,_payload jsonb)
RETURNS public.commandes LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_cmd public.commandes; v_l jsonb;
BEGIN
  UPDATE public.commandes SET date_commande=coalesce((_payload->>'date_commande')::date,date_commande), etablissement=coalesce(_payload->>'etablissement',etablissement), representant_nom=coalesce(_payload->>'representant_nom',representant_nom), telephone=coalesce(_payload->>'telephone',telephone), ville=coalesce(_payload->>'ville',ville), adresse=coalesce(_payload->>'adresse',adresse), observations=coalesce(_payload->>'observations',observations), remise_globale_pct=coalesce((_payload->>'remise_globale_pct')::numeric,remise_globale_pct), taux_tva=coalesce((_payload->>'taux_tva')::numeric,taux_tva), updated_at=now() WHERE commande_id=_commande_id RETURNING * INTO v_cmd;
  IF _payload ? 'lignes' THEN
    DELETE FROM public.commande_lignes WHERE commande_id=_commande_id;
    FOR v_l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP
      INSERT INTO public.commande_lignes(commande_id,produit_id,reference_produit,designation,quantite,prix_unitaire,remise_pct,montant_remise,total_ht_ligne,total_ligne)
      VALUES(_commande_id,NULLIF(v_l->>'produit_id','')::uuid,v_l->>'reference_produit',v_l->>'designation',coalesce((v_l->>'quantite')::int,1),coalesce((v_l->>'prix_unitaire')::numeric,0),coalesce((v_l->>'remise_pct')::numeric,0),(coalesce((v_l->>'quantite')::int,1)*coalesce((v_l->>'prix_unitaire')::numeric,0)*coalesce((v_l->>'remise_pct')::numeric,0)/100),(coalesce((v_l->>'quantite')::int,1)*coalesce((v_l->>'prix_unitaire')::numeric,0)*(1-coalesce((v_l->>'remise_pct')::numeric,0)/100)),(coalesce((v_l->>'quantite')::int,1)*coalesce((v_l->>'prix_unitaire')::numeric,0)*(1-coalesce((v_l->>'remise_pct')::numeric,0)/100)));
    END LOOP;
  END IF;
  PERFORM public.recalc_commande(_commande_id);
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=_commande_id; RETURN v_cmd;
END $$;

CREATE OR REPLACE FUNCTION public.soumettre_commande(_commande_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.commandes SET statut='en_attente_validation',updated_at=now() WHERE commande_id=_commande_id; END $$;
CREATE OR REPLACE FUNCTION public.generer_proforma_commande(_commande_id uuid)
RETURNS public.proformas LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE c record; p public.proformas; BEGIN SELECT * INTO c FROM public.commandes WHERE commande_id=_commande_id; INSERT INTO public.proformas(client_id,client_nom,montant_total,statut,notes) VALUES(c.client_id,c.client_nom,c.montant_total,'en_attente','Générée depuis commande '||c.reference) RETURNING * INTO p; INSERT INTO public.proforma_lignes(proforma_id,produit_id,designation,quantite,prix_unitaire,total_ligne) SELECT p.proforma_id,produit_id,designation,quantite,prix_unitaire,total_ligne FROM public.commande_lignes WHERE commande_id=_commande_id; RETURN p; END $$;
CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
RETURNS TABLE(facture_reference text, bl_reference text) LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE c record; f_ref text; b_ref text; BEGIN SELECT * INTO c FROM public.commandes WHERE commande_id=_commande_id; UPDATE public.commandes SET statut='validee',updated_at=now() WHERE commande_id=_commande_id; INSERT INTO public.factures(client_id,client_nom,commande_id,montant_total,montant_paye,statut,notes) VALUES(c.client_id,c.client_nom,_commande_id,c.montant_total,0,'impayee','Facturation de la commande '||c.reference) RETURNING reference INTO f_ref; INSERT INTO public.bons_livraison(commande_id,client_id,montant_total,statut,adresse_livraison) VALUES(_commande_id,c.client_id,c.montant_total,'brouillon',c.adresse) RETURNING reference INTO b_ref; facture_reference:=f_ref; bl_reference:=b_ref; RETURN NEXT; END $$;

CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(_produit_id uuid,_depot_id uuid,_nouvelle_quantite integer,_motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE v_current integer; v_delta integer; BEGIN INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES(_produit_id,_depot_id,0) ON CONFLICT(produit_id,depot_id) DO NOTHING; SELECT quantite INTO v_current FROM public.stocks_depots WHERE produit_id=_produit_id AND depot_id=_depot_id FOR UPDATE; UPDATE public.stocks_depots SET quantite=_nouvelle_quantite,updated_at=now() WHERE produit_id=_produit_id AND depot_id=_depot_id; UPDATE public.produits SET stock=(SELECT coalesce(sum(quantite),0) FROM public.stocks_depots WHERE produit_id=_produit_id),updated_at=now() WHERE produit_id=_produit_id; INSERT INTO public.stock_mouvements(produit_id,depot_id,type,quantite,stock_resultant,motif) VALUES(_produit_id,_depot_id,'ajustement',_nouvelle_quantite,(SELECT stock FROM public.produits WHERE produit_id=_produit_id),_motif); END $$;
CREATE OR REPLACE FUNCTION public.executer_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE t record; l record; BEGIN SELECT * INTO t FROM public.transferts WHERE transfert_id=_transfert_id FOR UPDATE; FOR l IN SELECT * FROM public.transfert_lignes WHERE transfert_id=_transfert_id LOOP PERFORM public.ajuster_stock_depot(l.produit_id,t.depot_source_id,greatest((SELECT coalesce(quantite,0) FROM public.stocks_depots WHERE produit_id=l.produit_id AND depot_id=t.depot_source_id)-l.quantite,0),'Transfert '||t.numero); PERFORM public.ajuster_stock_depot(l.produit_id,t.depot_destination_id,(SELECT coalesce(quantite,0) FROM public.stocks_depots WHERE produit_id=l.produit_id AND depot_id=t.depot_destination_id)+l.quantite,'Transfert '||t.numero); END LOOP; UPDATE public.transferts SET statut='expedie',date_expedition=now(),updated_at=now() WHERE transfert_id=_transfert_id; END $$;
CREATE OR REPLACE FUNCTION public.receptionner_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.transferts SET statut='recu',date_reception=now(),updated_at=now() WHERE transfert_id=_transfert_id; END $$;
CREATE OR REPLACE FUNCTION public.annuler_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.transferts SET statut='annule',updated_at=now() WHERE transfert_id=_transfert_id; END $$;

CREATE OR REPLACE FUNCTION public.confirmer_achat(_achat_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.achats SET statut='commande',date_commande=coalesce(date_commande,current_date),updated_at=now() WHERE achat_id=_achat_id; END $$;
CREATE OR REPLACE FUNCTION public.receptionner_achat(_achat_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.achats SET statut='recu',date_reception=coalesce(date_reception,current_date),updated_at=now() WHERE achat_id=_achat_id; END $$;
CREATE OR REPLACE FUNCTION public.payer_achat(_achat_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.achats SET statut='paye',date_paiement=coalesce(date_paiement,current_date),updated_at=now() WHERE achat_id=_achat_id; END $$;
CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
RETURNS public.achats LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE a public.achats; l jsonb; v_total numeric:=0; v_qty int:=0; BEGIN FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP v_total:=v_total+(coalesce((l->>'quantite')::int,0)*coalesce((l->>'prix_unitaire')::numeric,0)); v_qty:=v_qty+coalesce((l->>'quantite')::int,0); END LOOP; INSERT INTO public.achats(fournisseur_id,fournisseur_nom,libelle,montant,statut,date_achat,reference_fournisseur,notes,total_quantite,created_by,created_by_nom) SELECT (_payload->>'fournisseur_id')::uuid,f.raison_sociale,'Approvisionnement',v_total,'recu',coalesce((_payload->>'date_achat')::date,current_date),_payload->>'reference_fournisseur',_payload->>'notes',v_qty,auth.uid(),coalesce(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email') FROM public.fournisseurs f WHERE f.fournisseur_id=(_payload->>'fournisseur_id')::uuid RETURNING * INTO a; FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP INSERT INTO public.achat_lignes(achat_id,produit_id,reference_produit,designation,quantite,prix_unitaire,total_ligne) VALUES(a.achat_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',l->>'designation',coalesce((l->>'quantite')::int,0),coalesce((l->>'prix_unitaire')::numeric,0),coalesce((l->>'quantite')::int,0)*coalesce((l->>'prix_unitaire')::numeric,0)); IF l->>'produit_id' IS NOT NULL THEN INSERT INTO public.stock_mouvements(produit_id,depot_id,type,quantite,motif) VALUES((l->>'produit_id')::uuid,(_payload->>'depot_id')::uuid,'entree',coalesce((l->>'quantite')::int,0),'Approvisionnement '||a.reference); END IF; END LOOP; RETURN a; END $$;

CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
RETURNS public.specimens LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE s public.specimens; l jsonb; v_qty int:=0; BEGIN FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP v_qty:=v_qty+coalesce((l->>'quantite')::int,0); END LOOP; INSERT INTO public.specimens(numero,date_envoi,date_remise,client_id,etablissement,representant_nom,telephone,ville,adresse,donneur_nom,motif,observations,statut,total_quantite,nb_produits,created_by,gestionnaire_id,gestionnaire_nom) VALUES('SPC-'||to_char(now(),'YYYYMMDD-HH24MISS'),coalesce((_payload->>'date_envoi')::date,current_date),coalesce((_payload->>'date_envoi')::date,current_date),(_payload->>'client_id')::uuid,_payload->>'etablissement',_payload->>'representant_nom',_payload->>'telephone',_payload->>'ville',_payload->>'adresse',_payload->>'donneur_nom',_payload->>'motif',_payload->>'observations','enregistre',v_qty,jsonb_array_length(coalesce(_payload->'lignes','[]'::jsonb)),auth.uid(),auth.uid(),coalesce(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email')) RETURNING * INTO s; FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP INSERT INTO public.specimen_lignes(specimen_id,produit_id,reference_produit,designation,quantite,total_ligne) VALUES(s.specimen_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',l->>'designation',coalesce((l->>'quantite')::int,0),0); IF l->>'produit_id' IS NOT NULL THEN INSERT INTO public.stock_mouvements(produit_id,type,quantite,motif) VALUES((l->>'produit_id')::uuid,'sortie',coalesce((l->>'quantite')::int,0),'Spécimen '||s.numero); END IF; END LOOP; RETURN s; END $$;
CREATE OR REPLACE FUNCTION public.annuler_specimen(_specimen_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.specimens SET statut='annule',updated_at=now() WHERE specimen_id=_specimen_id; END $$;

CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
RETURNS public.retours LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE r public.retours; l jsonb; v_qty int:=0; BEGIN FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP v_qty:=v_qty+coalesce((l->>'quantite')::int,0); END LOOP; INSERT INTO public.retours(numero,date_retour,client_id,etablissement,representant_nom,telephone,ville,adresse,depot_id,observations,notes,statut,total_quantite,nb_produits,created_by,created_by_nom) VALUES('RET-'||to_char(now(),'YYYYMMDD-HH24MISS'),coalesce((_payload->>'date_retour')::date,current_date),(_payload->>'client_id')::uuid,_payload->>'etablissement',_payload->>'representant_nom',_payload->>'telephone',_payload->>'ville',_payload->>'adresse',NULLIF(_payload->>'depot_id','')::uuid,_payload->>'observations',_payload->>'notes','accepte',v_qty,jsonb_array_length(coalesce(_payload->'lignes','[]'::jsonb)),auth.uid(),coalesce(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email')) RETURNING * INTO r; FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP INSERT INTO public.retour_lignes(retour_id,produit_id,reference_produit,designation,quantite,motif) VALUES(r.retour_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',l->>'designation',coalesce((l->>'quantite')::int,0),l->>'motif'); IF l->>'produit_id' IS NOT NULL THEN INSERT INTO public.stock_mouvements(produit_id,depot_id,type,quantite,motif) VALUES((l->>'produit_id')::uuid,NULLIF(_payload->>'depot_id','')::uuid,'entree',coalesce((l->>'quantite')::int,0),'Retour '||r.numero); END IF; END LOOP; RETURN r; END $$;
CREATE OR REPLACE FUNCTION public.annuler_retour(_retour_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.retours SET statut='annule',updated_at=now() WHERE retour_id=_retour_id; END $$;

CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
RETURNS public.incidents LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE i public.incidents; l jsonb; v_qty int:=0; BEGIN FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP v_qty:=v_qty+coalesce((l->>'quantite')::int,0); END LOOP; INSERT INTO public.incidents(numero,type_incident,date_incident,depot_id,motif,observations,description,statut,total_quantite,nb_produits,responsable_id,responsable_nom) VALUES('INC-'||to_char(now(),'YYYYMMDD-HH24MISS'),_payload->>'type_incident',coalesce((_payload->>'date_incident')::date,current_date),(_payload->>'depot_id')::uuid,_payload->>'motif',_payload->>'observations',_payload->>'motif','declare',v_qty,jsonb_array_length(coalesce(_payload->'lignes','[]'::jsonb)),auth.uid(),coalesce(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email')) RETURNING * INTO i; FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_payload->'lignes','[]'::jsonb)) LOOP INSERT INTO public.incident_lignes(incident_id,produit_id,reference_produit,designation,quantite,impact_stock) VALUES(i.incident_id,NULLIF(l->>'produit_id','')::uuid,l->>'reference_produit',l->>'designation',coalesce((l->>'quantite')::int,0),-coalesce((l->>'quantite')::int,0)); END LOOP; RETURN i; END $$;
CREATE OR REPLACE FUNCTION public.annuler_incident(_incident_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.incidents SET statut='annule',updated_at=now() WHERE incident_id=_incident_id; END $$;

CREATE OR REPLACE FUNCTION public.creer_inventaire_physique(_payload jsonb)
RETURNS public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE inv public.inventaires; p record; BEGIN INSERT INTO public.inventaires(numero,reference,type_inventaire,depot_id,categorie_id,date_inventaire,statut,observations,created_by,created_by_nom) VALUES('INV-'||to_char(now(),'YYYYMMDD-HH24MISS'),'INV-'||to_char(now(),'YYYYMMDD-HH24MISS'),coalesce(_payload->>'type_inventaire','physique'),(_payload->>'depot_id')::uuid,NULLIF(_payload->>'categorie_id','')::uuid,coalesce((_payload->>'date_inventaire')::date,current_date),'brouillon',_payload->>'observations',auth.uid(),coalesce(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email')) RETURNING * INTO inv; FOR p IN SELECT pr.produit_id,pr.reference,pr.titre,coalesce(sd.quantite,pr.stock,0) stock,coalesce(pr.prix_achat,0) prix FROM public.produits pr LEFT JOIN public.stocks_depots sd ON sd.produit_id=pr.produit_id AND sd.depot_id=inv.depot_id WHERE pr.actif LOOP INSERT INTO public.inventaire_lignes(inventaire_id,produit_id,reference_produit,designation,stock_theorique,quantite_comptee,ecart,valeur_unitaire,valeur_ecart) VALUES(inv.inventaire_id,p.produit_id,p.reference,p.titre,p.stock,NULL,0,p.prix,0); END LOOP; UPDATE public.inventaires SET nb_produits=(SELECT count(*) FROM public.inventaire_lignes WHERE inventaire_id=inv.inventaire_id) WHERE inventaire_id=inv.inventaire_id RETURNING * INTO inv; RETURN inv; END $$;
CREATE OR REPLACE FUNCTION public.valider_inventaire_physique(_inventaire_id uuid,_lignes jsonb)
RETURNS public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE inv public.inventaires; l jsonb; BEGIN FOR l IN SELECT * FROM jsonb_array_elements(coalesce(_lignes,'[]'::jsonb)) LOOP UPDATE public.inventaire_lignes SET quantite_comptee=(l->>'quantite_comptee')::int, stock_compte=(l->>'quantite_comptee')::int, ecart=(l->>'quantite_comptee')::int-stock_theorique, valeur_ecart=((l->>'quantite_comptee')::int-stock_theorique)*valeur_unitaire, observation=l->>'observation' WHERE ligne_id=(l->>'ligne_id')::uuid; END LOOP; UPDATE public.inventaires SET statut='valide',validated_at=now(),nb_ecarts=(SELECT count(*) FROM public.inventaire_lignes WHERE inventaire_id=_inventaire_id AND coalesce(ecart,0)<>0),valeur_totale=(SELECT coalesce(sum(abs(valeur_ecart)),0) FROM public.inventaire_lignes WHERE inventaire_id=_inventaire_id),updated_at=now() WHERE inventaire_id=_inventaire_id RETURNING * INTO inv; RETURN inv; END $$;
CREATE OR REPLACE FUNCTION public.regulariser_inventaire(_inventaire_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ DECLARE inv record; l record; BEGIN SELECT * INTO inv FROM public.inventaires WHERE inventaire_id=_inventaire_id; FOR l IN SELECT * FROM public.inventaire_lignes WHERE inventaire_id=_inventaire_id AND quantite_comptee IS NOT NULL LOOP PERFORM public.ajuster_stock_depot(l.produit_id,inv.depot_id,l.quantite_comptee,'Régularisation inventaire '||inv.numero); END LOOP; UPDATE public.inventaires SET statut='regularise',regularized_at=now(),updated_at=now() WHERE inventaire_id=_inventaire_id; END $$;
CREATE OR REPLACE FUNCTION public.annuler_inventaire(_inventaire_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN UPDATE public.inventaires SET statut='annule',updated_at=now() WHERE inventaire_id=_inventaire_id; END $$;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
