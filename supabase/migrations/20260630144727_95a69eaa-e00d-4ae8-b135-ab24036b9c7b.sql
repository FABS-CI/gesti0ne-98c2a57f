
DO $$ BEGIN
  CREATE TYPE public.statut_livraison_cmd AS ENUM (
    'commande_creee','preparation','colisage_termine','en_attente_expedition',
    'expediee','en_cours_livraison','livree','livraison_partielle','livraison_confirmee','anomalie'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.livraisons_commande (
  livraison_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commande_id uuid NOT NULL UNIQUE REFERENCES public.commandes(commande_id) ON DELETE CASCADE,
  bl_id uuid REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  statut public.statut_livraison_cmd NOT NULL DEFAULT 'commande_creee',
  date_prevue_livraison date,
  date_expedition timestamptz, date_livraison timestamptz, date_confirmation timestamptz,
  transporteur text, chauffeur_nom text, vehicule text, ville_livraison text,
  quantite_commandee integer NOT NULL DEFAULT 0,
  quantite_preparee integer NOT NULL DEFAULT 0,
  quantite_expediee integer NOT NULL DEFAULT 0,
  quantite_livree integer NOT NULL DEFAULT 0,
  nb_cartons integer NOT NULL DEFAULT 0,
  progression_pct integer NOT NULL DEFAULT 0,
  derniere_maj timestamptz NOT NULL DEFAULT now(),
  observations text, anomalie_motif text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_livraisons_commande_commande ON public.livraisons_commande(commande_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_commande_statut ON public.livraisons_commande(statut);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.livraisons_commande TO authenticated;
GRANT ALL ON public.livraisons_commande TO service_role;
ALTER TABLE public.livraisons_commande ENABLE ROW LEVEL SECURITY;

CREATE POLICY "livraisons_cmd_read"
  ON public.livraisons_commande FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','comptable']::app_role[]));

CREATE POLICY "livraisons_cmd_write"
  ON public.livraisons_commande FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','service_logistique']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','service_logistique']::app_role[]));

CREATE TRIGGER trg_livraisons_cmd_updated BEFORE UPDATE ON public.livraisons_commande
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.livraison_commande_historique (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  livraison_id uuid NOT NULL REFERENCES public.livraisons_commande(livraison_id) ON DELETE CASCADE,
  ancien_statut public.statut_livraison_cmd,
  nouveau_statut public.statut_livraison_cmd NOT NULL,
  commentaire text, user_id uuid, user_nom text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lch_livraison ON public.livraison_commande_historique(livraison_id);

GRANT SELECT, INSERT ON public.livraison_commande_historique TO authenticated;
GRANT ALL ON public.livraison_commande_historique TO service_role;
ALTER TABLE public.livraison_commande_historique ENABLE ROW LEVEL SECURITY;

CREATE POLICY "lch_read"
  ON public.livraison_commande_historique FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','comptable']::app_role[]));

CREATE POLICY "lch_insert"
  ON public.livraison_commande_historique FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','service_logistique']::app_role[]));

CREATE TRIGGER trg_lch_immutable_upd
  BEFORE UPDATE OR DELETE ON public.livraison_commande_historique
  FOR EACH ROW EXECUTE FUNCTION public.guard_colis_historique_immutable();

CREATE OR REPLACE FUNCTION public.creer_livraison_commande(_commande_id uuid)
RETURNS public.livraisons_commande
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_liv public.livraisons_commande; v_cmd record; v_bl uuid; v_user text;
BEGIN
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  SELECT bl_id INTO v_bl FROM public.bons_livraison WHERE commande_id = _commande_id LIMIT 1;
  v_user := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  INSERT INTO public.livraisons_commande(commande_id, bl_id, statut, ville_livraison, quantite_commandee, progression_pct)
  VALUES (_commande_id, v_bl, 'commande_creee', v_cmd.ville, COALESCE(v_cmd.total_quantite,0), 0)
  ON CONFLICT (commande_id) DO UPDATE SET
    bl_id = COALESCE(EXCLUDED.bl_id, public.livraisons_commande.bl_id),
    quantite_commandee = EXCLUDED.quantite_commandee,
    ville_livraison = COALESCE(EXCLUDED.ville_livraison, public.livraisons_commande.ville_livraison),
    updated_at = now()
  RETURNING * INTO v_liv;
  INSERT INTO public.livraison_commande_historique(livraison_id, nouveau_statut, commentaire, user_id, user_nom)
  VALUES (v_liv.livraison_id, v_liv.statut, 'Création du suivi de livraison', auth.uid(), v_user);
  RETURN v_liv;
END $$;

CREATE OR REPLACE FUNCTION public.recalculer_livraison_commande(_livraison_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cmd uuid; v_nb int; v_expediee int; v_livree int; v_qte_cmd int; v_pct int; v_statut public.statut_livraison_cmd;
BEGIN
  SELECT commande_id, quantite_commandee, statut INTO v_cmd, v_qte_cmd, v_statut
    FROM public.livraisons_commande WHERE livraison_id = _livraison_id;
  SELECT COUNT(*) INTO v_nb FROM public.colis WHERE commande_id = v_cmd;
  SELECT
    COUNT(*) FILTER (WHERE statut_logistique IN ('en_cours_livraison','arrive_client','livre','depose_gare','en_cours_expedition','arrive_ville','remis_client')),
    COUNT(*) FILTER (WHERE statut_logistique IN ('livre','remis_client'))
  INTO v_expediee, v_livree FROM public.colis WHERE commande_id = v_cmd;
  v_pct := CASE v_statut
    WHEN 'commande_creee' THEN 10 WHEN 'preparation' THEN 25 WHEN 'colisage_termine' THEN 50
    WHEN 'en_attente_expedition' THEN 60 WHEN 'expediee' THEN 75 WHEN 'en_cours_livraison' THEN 85
    WHEN 'livraison_partielle' THEN 80 WHEN 'livree' THEN 95 WHEN 'livraison_confirmee' THEN 100 ELSE 0 END;
  UPDATE public.livraisons_commande SET
    nb_cartons = COALESCE(v_nb,0),
    quantite_expediee = CASE WHEN COALESCE(v_nb,0)=0 THEN 0 ELSE ROUND(v_qte_cmd::numeric * v_expediee::numeric / v_nb::numeric)::int END,
    quantite_livree = CASE WHEN COALESCE(v_nb,0)=0 THEN 0 ELSE ROUND(v_qte_cmd::numeric * v_livree::numeric / v_nb::numeric)::int END,
    progression_pct = v_pct, derniere_maj = now(), updated_at = now()
  WHERE livraison_id = _livraison_id;
END $$;

CREATE OR REPLACE FUNCTION public.trg_colis_sync_livraison_cmd()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_liv uuid;
BEGIN
  IF NEW.commande_id IS NULL THEN RETURN NEW; END IF;
  SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = NEW.commande_id;
  IF v_liv IS NULL THEN
    PERFORM public.creer_livraison_commande(NEW.commande_id);
    SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = NEW.commande_id;
  END IF;
  PERFORM public.recalculer_livraison_commande(v_liv);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_colis_sync_livcmd ON public.colis;
CREATE TRIGGER trg_colis_sync_livcmd
  AFTER INSERT OR UPDATE OF statut_logistique, statut ON public.colis
  FOR EACH ROW EXECUTE FUNCTION public.trg_colis_sync_livraison_cmd();

CREATE OR REPLACE FUNCTION public.changer_statut_livraison_commande(
  _livraison_id uuid, _nouveau_statut public.statut_livraison_cmd, _commentaire text DEFAULT NULL
) RETURNS public.livraisons_commande
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_liv public.livraisons_commande; v_ancien public.statut_livraison_cmd; v_user text; v_notif_titre text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT public.has_any_role(auth.uid(),
        ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;
  SELECT * INTO v_liv FROM public.livraisons_commande WHERE livraison_id = _livraison_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Livraison introuvable'; END IF;
  v_ancien := v_liv.statut;
  v_user := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  UPDATE public.livraisons_commande SET
    statut = _nouveau_statut,
    date_expedition = CASE WHEN _nouveau_statut='expediee' THEN COALESCE(date_expedition, now()) ELSE date_expedition END,
    date_livraison = CASE WHEN _nouveau_statut IN ('livree','livraison_partielle') THEN COALESCE(date_livraison, now()) ELSE date_livraison END,
    date_confirmation = CASE WHEN _nouveau_statut='livraison_confirmee' THEN COALESCE(date_confirmation, now()) ELSE date_confirmation END,
    derniere_maj = now(), updated_at = now()
  WHERE livraison_id = _livraison_id;
  PERFORM public.recalculer_livraison_commande(_livraison_id);
  INSERT INTO public.livraison_commande_historique(livraison_id, ancien_statut, nouveau_statut, commentaire, user_id, user_nom)
  VALUES (_livraison_id, v_ancien, _nouveau_statut, _commentaire, auth.uid(), v_user);
  v_notif_titre := CASE _nouveau_statut
    WHEN 'colisage_termine' THEN 'Colisage terminé'
    WHEN 'en_attente_expedition' THEN 'Commande prête à être expédiée'
    WHEN 'expediee' THEN 'Commande expédiée'
    WHEN 'en_cours_livraison' THEN 'Livraison en cours'
    WHEN 'livree' THEN 'Livraison effectuée'
    WHEN 'livraison_confirmee' THEN 'Livraison confirmée'
    ELSE NULL END;
  IF v_notif_titre IS NOT NULL THEN
    INSERT INTO public.notifications(titre, message, type_notification, lu, date_notification)
    VALUES (v_notif_titre, 'Livraison ' || _livraison_id::text || ' : ' || _nouveau_statut::text, 'livraison', false, current_date);
  END IF;
  SELECT * INTO v_liv FROM public.livraisons_commande WHERE livraison_id = _livraison_id;
  RETURN v_liv;
END $$;

CREATE OR REPLACE FUNCTION public.enregistrer_livraison_partielle(
  _livraison_id uuid, _quantite_livree integer, _commentaire text DEFAULT NULL
) RETURNS public.livraisons_commande
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_liv public.livraisons_commande; v_total int; v_new_statut public.statut_livraison_cmd; v_ancien public.statut_livraison_cmd;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
        ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;
  SELECT * INTO v_liv FROM public.livraisons_commande WHERE livraison_id = _livraison_id FOR UPDATE;
  v_ancien := v_liv.statut;
  v_total := v_liv.quantite_livree + _quantite_livree;
  v_new_statut := CASE WHEN v_total >= v_liv.quantite_commandee THEN 'livree'::public.statut_livraison_cmd
                       ELSE 'livraison_partielle'::public.statut_livraison_cmd END;
  UPDATE public.livraisons_commande
     SET quantite_livree = v_total, statut = v_new_statut,
         date_livraison = COALESCE(date_livraison, now()), derniere_maj = now()
   WHERE livraison_id = _livraison_id RETURNING * INTO v_liv;
  INSERT INTO public.livraison_commande_historique(livraison_id, ancien_statut, nouveau_statut, commentaire, user_id, user_nom)
  VALUES (_livraison_id, v_ancien, v_new_statut,
    COALESCE(_commentaire,'') || ' (livré: ' || _quantite_livree || ')',
    auth.uid(), COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email'));
  RETURN v_liv;
END $$;

CREATE OR REPLACE FUNCTION public.signaler_anomalie_livraison(
  _livraison_id uuid, _motif text
) RETURNS public.livraisons_commande
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_liv public.livraisons_commande; v_ancien public.statut_livraison_cmd;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
        ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;
  SELECT statut INTO v_ancien FROM public.livraisons_commande WHERE livraison_id = _livraison_id;
  UPDATE public.livraisons_commande
     SET statut = 'anomalie', anomalie_motif = _motif, derniere_maj = now()
   WHERE livraison_id = _livraison_id RETURNING * INTO v_liv;
  INSERT INTO public.livraison_commande_historique(livraison_id, ancien_statut, nouveau_statut, commentaire, user_id, user_nom)
  VALUES (_livraison_id, v_ancien, 'anomalie', _motif, auth.uid(),
          COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email'));
  RETURN v_liv;
END $$;

CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
 RETURNS TABLE(facture_reference text, bl_reference text)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE c record; f_ref text; b_ref text; l record; v_depot uuid; v_actuel int; v_bl_id uuid;
BEGIN
  SELECT * INTO c FROM public.commandes WHERE commande_id=_commande_id;
  v_depot := public.resolve_depot_sortie(c.depot_id, 'commandes');
  FOR l IN SELECT produit_id,quantite FROM public.commande_lignes
            WHERE commande_id=_commande_id AND produit_id IS NOT NULL LOOP
    INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES(l.produit_id,v_depot,0)
      ON CONFLICT(produit_id,depot_id) DO NOTHING;
    SELECT COALESCE(quantite,0) INTO v_actuel FROM public.stocks_depots
      WHERE produit_id=l.produit_id AND depot_id=v_depot FOR UPDATE;
    PERFORM public.ajuster_stock_depot(l.produit_id, v_depot, GREATEST(v_actuel-l.quantite,0),
      'Vente commande '||c.reference, 'commande', _commande_id, c.reference, 'commandes', NULL);
  END LOOP;
  UPDATE public.commandes SET statut='validee',depot_id=v_depot,updated_at=now() WHERE commande_id=_commande_id;
  INSERT INTO public.factures(client_id,client_nom,commande_id,montant_total,montant_paye,statut,notes)
    VALUES(c.client_id,c.client_nom,_commande_id,c.montant_total,0,'impayee','Facturation de la commande '||c.reference)
    RETURNING reference INTO f_ref;
  INSERT INTO public.bons_livraison(commande_id,client_id,montant_total,statut,adresse_livraison)
    VALUES(_commande_id,c.client_id,c.montant_total,'brouillon',c.adresse)
    RETURNING bl_id, reference INTO v_bl_id, b_ref;
  PERFORM public.creer_livraison_commande(_commande_id);
  UPDATE public.livraisons_commande SET statut='preparation', bl_id=v_bl_id WHERE commande_id=_commande_id;
  facture_reference:=f_ref; bl_reference:=b_ref; RETURN NEXT;
END $function$;

CREATE OR REPLACE FUNCTION public.creer_colisage(_bl_id uuid, _payload jsonb)
 RETURNS SETOF colis LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_bl record; v_nb int := GREATEST(COALESCE((_payload->>'nb_cartons')::int, 1), 1);
  v_mode text := _payload->>'mode_acheminement';
  v_responsable text := COALESCE(_payload->>'responsable_nom', auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  v_client_nom text; i int; v_ref text; v_liv uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF v_mode NOT IN ('livraison','expedition') THEN RAISE EXCEPTION 'Mode d''acheminement invalide (livraison|expedition)'; END IF;
  SELECT bl.*, c.client_nom AS cnom INTO v_bl FROM public.bons_livraison bl
    LEFT JOIN public.commandes c ON c.commande_id = bl.commande_id WHERE bl.bl_id = _bl_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de livraison introuvable'; END IF;
  v_client_nom := COALESCE(v_bl.cnom, '');
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  FOR i IN 1..v_nb LOOP
    v_ref := v_bl.reference || '-C' || lpad(i::text, 2, '0');
    INSERT INTO public.colis(reference, destinataire, contenu, transporteur, date_envoi, statut,
      bl_id, commande_id, numero_carton, nb_cartons, responsable_id, responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule, quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone, observations, date_colisage)
    VALUES (v_ref, v_client_nom, 'Carton '||i||'/'||v_nb||' — BL '||v_bl.reference,
      CASE WHEN v_mode='expedition' THEN _payload->>'gare_depart' ELSE _payload->>'livreur_nom' END,
      COALESCE((_payload->>'date_colisage')::date, current_date), 'en_preparation',
      _bl_id, v_bl.commande_id, i, v_nb, auth.uid(), v_responsable, v_mode,
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      _payload->>'observations', COALESCE((_payload->>'date_colisage')::timestamptz, now()));
  END LOOP;
  UPDATE public.bons_livraison SET statut = 'colisage_termine', updated_at = now() WHERE bl_id = _bl_id;
  IF v_bl.commande_id IS NOT NULL THEN
    SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = v_bl.commande_id;
    IF v_liv IS NULL THEN
      PERFORM public.creer_livraison_commande(v_bl.commande_id);
      SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = v_bl.commande_id;
    END IF;
    UPDATE public.livraisons_commande SET
      statut='colisage_termine', bl_id=_bl_id,
      transporteur = COALESCE(_payload->>'livreur_nom', _payload->>'gare_depart'),
      chauffeur_nom = _payload->>'livreur_nom',
      vehicule = _payload->>'vehicule',
      ville_livraison = COALESCE(_payload->>'ville_livraison', _payload->>'ville_destination', ville_livraison),
      nb_cartons = v_nb, derniere_maj = now()
      WHERE livraison_id = v_liv;
    PERFORM public.recalculer_livraison_commande(v_liv);
    INSERT INTO public.livraison_commande_historique(livraison_id, nouveau_statut, commentaire, user_id, user_nom)
    VALUES (v_liv, 'colisage_termine', 'Colisage validé ('||v_nb||' carton(s))', auth.uid(), v_responsable);
  END IF;
  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END $function$;

INSERT INTO public.livraisons_commande (commande_id, bl_id, statut, ville_livraison, quantite_commandee, nb_cartons, progression_pct)
SELECT c.commande_id,
       (SELECT bl_id FROM public.bons_livraison bl WHERE bl.commande_id = c.commande_id LIMIT 1),
       CASE
         WHEN EXISTS(SELECT 1 FROM public.colis k WHERE k.commande_id=c.commande_id AND k.statut_logistique IN ('livre','remis_client')) THEN 'livree'::public.statut_livraison_cmd
         WHEN EXISTS(SELECT 1 FROM public.colis k WHERE k.commande_id=c.commande_id) THEN 'colisage_termine'::public.statut_livraison_cmd
         WHEN c.statut='validee' THEN 'preparation'::public.statut_livraison_cmd
         ELSE 'commande_creee'::public.statut_livraison_cmd
       END,
       c.ville, COALESCE(c.total_quantite,0),
       (SELECT COUNT(*) FROM public.colis k WHERE k.commande_id=c.commande_id), 0
FROM public.commandes c
WHERE c.statut IN ('validee','facturee','livree')
ON CONFLICT (commande_id) DO NOTHING;

UPDATE public.livraisons_commande SET progression_pct = CASE statut
    WHEN 'commande_creee' THEN 10 WHEN 'preparation' THEN 25
    WHEN 'colisage_termine' THEN 50 WHEN 'en_attente_expedition' THEN 60
    WHEN 'expediee' THEN 75 WHEN 'en_cours_livraison' THEN 85
    WHEN 'livraison_partielle' THEN 80 WHEN 'livree' THEN 95
    WHEN 'livraison_confirmee' THEN 100 ELSE 0 END;
