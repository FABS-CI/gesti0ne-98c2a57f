-- Enums
DO $$ BEGIN
  CREATE TYPE public.livsuivi_type AS ENUM ('direct','expedition');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.livsuivi_statut AS ENUM (
    'preparee',
    'remise_livreur','depart_depot','arrive_client','livree',
    'remise_transporteur','expediee','arrivee_gare','retiree_client','livree_locale'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.livsuivi_tournees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL DEFAULT ('TRN-'||to_char(now(),'YYYYMMDD-HH24MISS')),
  type public.livsuivi_type NOT NULL,
  livreur_nom text NOT NULL,
  livreur_contact text,
  vehicule text,
  date_depart date NOT NULL DEFAULT current_date,
  statut text NOT NULL DEFAULT 'ouverte',
  observations text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_nom text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.livsuivi_tournees TO authenticated;
GRANT ALL ON public.livsuivi_tournees TO service_role;
ALTER TABLE public.livsuivi_tournees ENABLE ROW LEVEL SECURITY;
CREATE POLICY "livsuivi_tournees_read" ON public.livsuivi_tournees FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial']::app_role[]));
CREATE POLICY "livsuivi_tournees_write" ON public.livsuivi_tournees FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]));

CREATE TABLE IF NOT EXISTS public.livsuivi_commandes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commande_id uuid NOT NULL UNIQUE REFERENCES public.commandes(commande_id) ON DELETE CASCADE,
  tournee_id uuid REFERENCES public.livsuivi_tournees(id) ON DELETE SET NULL,
  type_livraison public.livsuivi_type NOT NULL DEFAULT 'direct',
  gare_depot text,
  gare_destination text,
  ville_destination text,
  livreur_nom text,
  vehicule text,
  receptionnaire_nom text,
  statut public.livsuivi_statut NOT NULL DEFAULT 'preparee',
  derniere_maj timestamptz NOT NULL DEFAULT now(),
  cloturee boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_livsuivi_commandes_tournee ON public.livsuivi_commandes(tournee_id);
CREATE INDEX IF NOT EXISTS idx_livsuivi_commandes_statut ON public.livsuivi_commandes(statut);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.livsuivi_commandes TO authenticated;
GRANT ALL ON public.livsuivi_commandes TO service_role;
ALTER TABLE public.livsuivi_commandes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "livsuivi_commandes_read" ON public.livsuivi_commandes FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','comptable','secretariat']::app_role[]));
CREATE POLICY "livsuivi_commandes_write" ON public.livsuivi_commandes FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]));

CREATE TABLE IF NOT EXISTS public.livsuivi_historique (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  livraison_id uuid NOT NULL REFERENCES public.livsuivi_commandes(id) ON DELETE CASCADE,
  etape public.livsuivi_statut NOT NULL,
  commentaire text,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  user_nom text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_livsuivi_historique_liv ON public.livsuivi_historique(livraison_id, created_at);
GRANT SELECT, INSERT ON public.livsuivi_historique TO authenticated;
GRANT ALL ON public.livsuivi_historique TO service_role;
ALTER TABLE public.livsuivi_historique ENABLE ROW LEVEL SECURITY;
CREATE POLICY "livsuivi_historique_read" ON public.livsuivi_historique FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','comptable','secretariat']::app_role[]));
CREATE POLICY "livsuivi_historique_insert" ON public.livsuivi_historique FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]));

CREATE OR REPLACE FUNCTION public.livsuivi_guard_historique()
RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
  IF public.has_role(auth.uid(),'super_admin') THEN RETURN COALESCE(NEW,OLD); END IF;
  RAISE EXCEPTION 'Historique non modifiable';
END $$;
DROP TRIGGER IF EXISTS trg_livsuivi_histo_immut ON public.livsuivi_historique;
CREATE TRIGGER trg_livsuivi_histo_immut BEFORE UPDATE OR DELETE ON public.livsuivi_historique
  FOR EACH ROW EXECUTE FUNCTION public.livsuivi_guard_historique();

DROP TRIGGER IF EXISTS trg_livsuivi_tournees_updated ON public.livsuivi_tournees;
CREATE TRIGGER trg_livsuivi_tournees_updated BEFORE UPDATE ON public.livsuivi_tournees
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS trg_livsuivi_commandes_updated ON public.livsuivi_commandes;
CREATE TRIGGER trg_livsuivi_commandes_updated BEFORE UPDATE ON public.livsuivi_commandes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.livsuivi_next_etape(_type public.livsuivi_type, _current public.livsuivi_statut)
RETURNS public.livsuivi_statut LANGUAGE plpgsql IMMUTABLE SET search_path=public AS $$
BEGIN
  IF _type='direct' THEN
    RETURN CASE _current
      WHEN 'preparee' THEN 'remise_livreur'::public.livsuivi_statut
      WHEN 'remise_livreur' THEN 'depart_depot'::public.livsuivi_statut
      WHEN 'depart_depot' THEN 'arrive_client'::public.livsuivi_statut
      WHEN 'arrive_client' THEN 'livree'::public.livsuivi_statut
      ELSE NULL END;
  ELSE
    RETURN CASE _current
      WHEN 'preparee' THEN 'remise_transporteur'::public.livsuivi_statut
      WHEN 'remise_transporteur' THEN 'expediee'::public.livsuivi_statut
      WHEN 'expediee' THEN 'arrivee_gare'::public.livsuivi_statut
      WHEN 'arrivee_gare' THEN 'retiree_client'::public.livsuivi_statut
      ELSE NULL END;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.livsuivi_from_bl()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_cmd uuid; v_liv uuid; v_user text;
BEGIN
  IF NEW.statut <> 'colisage_termine' OR NEW.commande_id IS NULL THEN RETURN NEW; END IF;
  v_cmd := NEW.commande_id;
  v_user := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email','système');
  INSERT INTO public.livsuivi_commandes(commande_id, statut) VALUES (v_cmd, 'preparee'::public.livsuivi_statut)
    ON CONFLICT (commande_id) DO NOTHING
    RETURNING id INTO v_liv;
  IF v_liv IS NULL THEN
    SELECT id INTO v_liv FROM public.livsuivi_commandes WHERE commande_id = v_cmd;
  ELSE
    INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, user_id, user_nom)
    VALUES (v_liv, 'preparee', 'Colisage terminé — commande prête', auth.uid(), v_user);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_livsuivi_from_bl ON public.bons_livraison;
CREATE TRIGGER trg_livsuivi_from_bl AFTER INSERT OR UPDATE OF statut ON public.bons_livraison
  FOR EACH ROW EXECUTE FUNCTION public.livsuivi_from_bl();

CREATE OR REPLACE FUNCTION public.livsuivi_notify_client()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_cmd record; v_msg text; v_titre text;
BEGIN
  SELECT c.reference, c.client_id, c.client_nom INTO v_cmd
    FROM public.livsuivi_commandes lc
    JOIN public.commandes c ON c.commande_id = lc.commande_id
   WHERE lc.id = NEW.livraison_id;
  IF NOT FOUND THEN RETURN NEW; END IF;
  v_msg := CASE NEW.etape
    WHEN 'preparee' THEN 'Votre commande '||v_cmd.reference||' est prête pour la livraison'
    WHEN 'remise_livreur' THEN 'Votre commande '||v_cmd.reference||' a été remise au livreur'
    WHEN 'depart_depot' THEN 'Votre commande '||v_cmd.reference||' vient de quitter notre dépôt'
    WHEN 'arrive_client' THEN 'Le livreur est arrivé à votre adresse pour la commande '||v_cmd.reference
    WHEN 'livree' THEN 'Votre commande '||v_cmd.reference||' a été livrée avec succès'
    WHEN 'remise_transporteur' THEN 'Votre commande '||v_cmd.reference||' a été remise au transporteur'
    WHEN 'expediee' THEN 'Votre commande '||v_cmd.reference||' a été expédiée'
    WHEN 'arrivee_gare' THEN 'Votre colis '||v_cmd.reference||' est arrivé à la gare'
    WHEN 'retiree_client' THEN 'Votre commande '||v_cmd.reference||' a été retirée avec succès'
    WHEN 'livree_locale' THEN 'Votre commande '||v_cmd.reference||' a été livrée localement'
    ELSE 'Mise à jour de votre commande '||v_cmd.reference END;
  v_titre := 'Suivi livraison — '||v_cmd.reference;
  BEGIN
    PERFORM public.creer_notification(v_titre, v_msg, 'info', 'livraison', 'livsuivi_commandes',
      NEW.livraison_id, v_cmd.reference, '/livraison-suivi/'||v_cmd.reference,
      'directeur_commercial', NULL, 'normale');
  EXCEPTION WHEN OTHERS THEN NULL; END;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_livsuivi_notify ON public.livsuivi_historique;
CREATE TRIGGER trg_livsuivi_notify AFTER INSERT ON public.livsuivi_historique
  FOR EACH ROW EXECUTE FUNCTION public.livsuivi_notify_client();

CREATE OR REPLACE FUNCTION public.livsuivi_avancer(
  _livraison_id uuid, _etape public.livsuivi_statut,
  _meta jsonb DEFAULT '{}'::jsonb, _commentaire text DEFAULT NULL
) RETURNS public.livsuivi_commandes
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_liv public.livsuivi_commandes; v_next public.livsuivi_statut; v_user text;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  SELECT * INTO v_liv FROM public.livsuivi_commandes WHERE id=_livraison_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Livraison introuvable'; END IF;
  v_next := public.livsuivi_next_etape(v_liv.type_livraison, v_liv.statut);
  IF v_liv.type_livraison='expedition' AND v_liv.statut='arrivee_gare' AND _etape='livree_locale' THEN
    v_next := 'livree_locale';
  END IF;
  IF v_next IS NULL OR _etape <> v_next THEN
    RAISE EXCEPTION 'Transition non autorisée: % -> %', v_liv.statut, _etape;
  END IF;
  v_user := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  UPDATE public.livsuivi_commandes SET
    statut = _etape,
    livreur_nom = COALESCE(_meta->>'livreur_nom', livreur_nom),
    vehicule = COALESCE(_meta->>'vehicule', vehicule),
    gare_destination = COALESCE(_meta->>'gare_destination', gare_destination),
    ville_destination = COALESCE(_meta->>'ville_destination', ville_destination),
    receptionnaire_nom = COALESCE(_meta->>'receptionnaire_nom', receptionnaire_nom),
    cloturee = (_etape IN ('livree','retiree_client','livree_locale')),
    derniere_maj = now()
  WHERE id=_livraison_id RETURNING * INTO v_liv;
  INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, meta, user_id, user_nom)
  VALUES (_livraison_id, _etape, _commentaire, COALESCE(_meta,'{}'::jsonb), auth.uid(), v_user);
  RETURN v_liv;
END $$;

CREATE OR REPLACE FUNCTION public.livsuivi_creer_tournee(_payload jsonb)
RETURNS public.livsuivi_tournees
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_t public.livsuivi_tournees; v_ids uuid[]; v_user text;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  v_user := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  INSERT INTO public.livsuivi_tournees(type, livreur_nom, livreur_contact, vehicule, date_depart, observations, created_by, created_by_nom)
  VALUES ((_payload->>'type')::public.livsuivi_type, _payload->>'livreur_nom', _payload->>'livreur_contact',
    _payload->>'vehicule', COALESCE((_payload->>'date_depart')::date, current_date),
    _payload->>'observations', auth.uid(), v_user) RETURNING * INTO v_t;
  IF _payload ? 'commande_ids' THEN
    SELECT ARRAY(SELECT jsonb_array_elements_text(_payload->'commande_ids'))::uuid[] INTO v_ids;
    UPDATE public.livsuivi_commandes SET tournee_id = v_t.id, type_livraison = v_t.type
      WHERE id = ANY(v_ids) AND statut = 'preparee';
  END IF;
  RETURN v_t;
END $$;

CREATE OR REPLACE FUNCTION public.livsuivi_avancer_masse(
  _tournee_id uuid, _etape public.livsuivi_statut,
  _meta jsonb DEFAULT '{}'::jsonb, _filtre_gare text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_row record; v_count int := 0;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  FOR v_row IN
    SELECT id FROM public.livsuivi_commandes
     WHERE tournee_id = _tournee_id
       AND (_filtre_gare IS NULL OR gare_destination = _filtre_gare)
       AND public.livsuivi_next_etape(type_livraison, statut) = _etape
  LOOP
    PERFORM public.livsuivi_avancer(v_row.id, _etape, _meta, 'Action groupée tournée');
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END $$;

DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.livsuivi_commandes;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.livsuivi_historique;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.livsuivi_tournees;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

INSERT INTO public.livsuivi_commandes(commande_id, statut)
SELECT DISTINCT bl.commande_id, 'preparee'::public.livsuivi_statut
  FROM public.bons_livraison bl
 WHERE bl.commande_id IS NOT NULL AND bl.statut = 'colisage_termine'
ON CONFLICT (commande_id) DO NOTHING;
