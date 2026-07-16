
-- =========================================================
-- MODULE TOURNÉE / LIVRAISON — reconstruction best-effort
-- =========================================================

-- ---------- Livreurs : alias nom ----------
ALTER TABLE public.livreurs ADD COLUMN IF NOT EXISTS nom text;
UPDATE public.livreurs SET nom = nom_complet WHERE nom IS NULL;

-- ---------- Bons de livraison ----------
ALTER TABLE public.bons_livraison
  ADD COLUMN IF NOT EXISTS adresse_livraison text,
  ADD COLUMN IF NOT EXISTS transporteur text;

-- ---------- Colis : compléments ----------
ALTER TABLE public.colis
  ADD COLUMN IF NOT EXISTS commande_id uuid,
  ADD COLUMN IF NOT EXISTS contenu text,
  ADD COLUMN IF NOT EXISTS date_envoi timestamptz,
  ADD COLUMN IF NOT EXISTS transporteur text;
CREATE INDEX IF NOT EXISTS idx_colis_commande ON public.colis(commande_id);
CREATE INDEX IF NOT EXISTS idx_colis_tournee ON public.colis(tournee_id);

-- ---------- Transporteurs ----------
CREATE TABLE IF NOT EXISTS public.transporteurs (
  transporteur_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  telephone text,
  contact text,
  type text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transporteurs TO authenticated;
GRANT ALL ON public.transporteurs TO service_role;
ALTER TABLE public.transporteurs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "transporteurs_all_authenticated" ON public.transporteurs;
CREATE POLICY "transporteurs_all_authenticated" ON public.transporteurs FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "transporteurs_service_role" ON public.transporteurs;
CREATE POLICY "transporteurs_service_role" ON public.transporteurs FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP TRIGGER IF EXISTS trg_transporteurs_updated_at ON public.transporteurs;
CREATE TRIGGER trg_transporteurs_updated_at BEFORE UPDATE ON public.transporteurs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ---------- Gares ----------
CREATE TABLE IF NOT EXISTS public.gares (
  gare_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  ville text,
  code text,
  actif boolean NOT NULL DEFAULT true,
  transporteur_id uuid REFERENCES public.transporteurs(transporteur_id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gares TO authenticated;
GRANT ALL ON public.gares TO service_role;
ALTER TABLE public.gares ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "gares_all_authenticated" ON public.gares;
CREATE POLICY "gares_all_authenticated" ON public.gares FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "gares_service_role" ON public.gares;
CREATE POLICY "gares_service_role" ON public.gares FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP TRIGGER IF EXISTS trg_gares_updated_at ON public.gares;
CREATE TRIGGER trg_gares_updated_at BEFORE UPDATE ON public.gares
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ---------- Expeditions ----------
CREATE TABLE IF NOT EXISTS public.expeditions (
  expedition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL,
  bl_id uuid REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  transporteur text,
  transporteur_id uuid REFERENCES public.transporteurs(transporteur_id) ON DELETE SET NULL,
  date_depart timestamptz,
  date_arrivee_prevue timestamptz,
  statut text NOT NULL DEFAULT 'planifiee',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expeditions TO authenticated;
GRANT ALL ON public.expeditions TO service_role;
ALTER TABLE public.expeditions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "expeditions_all_authenticated" ON public.expeditions;
CREATE POLICY "expeditions_all_authenticated" ON public.expeditions FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "expeditions_service_role" ON public.expeditions;
CREATE POLICY "expeditions_service_role" ON public.expeditions FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP TRIGGER IF EXISTS trg_expeditions_updated_at ON public.expeditions;
CREATE TRIGGER trg_expeditions_updated_at BEFORE UPDATE ON public.expeditions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ---------- Tournees : compléter les colonnes ----------
ALTER TABLE public.tournees
  ADD COLUMN IF NOT EXISTS heure_depart text,
  ADD COLUMN IF NOT EXISTS depot_depart_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS responsable_nom text,
  ADD COLUMN IF NOT EXISTS chauffeur_nom text,
  ADD COLUMN IF NOT EXISTS type_tournee text DEFAULT 'direct',
  ADD COLUMN IF NOT EXISTS nb_colis integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_cartons integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_clients integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_carburant numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_peages numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_repas numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_livraison numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_expeditions numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_manutentions numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_autres numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cout_total numeric GENERATED ALWAYS AS (
    COALESCE(cout_carburant,0) + COALESCE(cout_peages,0) + COALESCE(cout_repas,0)
    + COALESCE(cout_livraison,0) + COALESCE(cout_expeditions,0)
    + COALESCE(cout_manutentions,0) + COALESCE(cout_autres,0)
  ) STORED,
  ADD COLUMN IF NOT EXISTS validation_statut text DEFAULT 'brouillon',
  ADD COLUMN IF NOT EXISTS mode_reglement text,
  ADD COLUMN IF NOT EXISTS validation_at timestamptz,
  ADD COLUMN IF NOT EXISTS validation_by uuid,
  ADD COLUMN IF NOT EXISTS validation_commentaire text,
  ADD COLUMN IF NOT EXISTS ecriture_id uuid;
ALTER TABLE public.tournees ALTER COLUMN statut SET DEFAULT 'preparee';

-- ---------- Livraisons : compléter les colonnes ----------
ALTER TABLE public.livraisons
  ADD COLUMN IF NOT EXISTS bl_id uuid REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS expedition_id uuid REFERENCES public.expeditions(expedition_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS client_id uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS transporteur_id uuid REFERENCES public.transporteurs(transporteur_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS gare_depart_id uuid REFERENCES public.gares(gare_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS gare_arrivee_id uuid REFERENCES public.gares(gare_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS commune text,
  ADD COLUMN IF NOT EXISTS telephone_dest text,
  ADD COLUMN IF NOT EXISTS contact_dest text,
  ADD COLUMN IF NOT EXISTS client_nom text,
  ADD COLUMN IF NOT EXISTS transporteur text,
  ADD COLUMN IF NOT EXISTS figee boolean NOT NULL DEFAULT false;
ALTER TABLE public.livraisons ALTER COLUMN statut SET DEFAULT 'planifiee';

-- ---------- livraisons_commande (lignes de livraison par commande dans une tournée) ----------
CREATE TABLE IF NOT EXISTS public.livraisons_commande (
  livraison_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournee_id uuid REFERENCES public.tournees(tournee_id) ON DELETE CASCADE,
  commande_id uuid REFERENCES public.commandes(commande_id) ON DELETE CASCADE,
  bl_id uuid REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  statut text DEFAULT 'planifiee',
  type_livraison text DEFAULT 'direct',
  gare_nom text,
  ville_livraison text,
  nb_cartons integer DEFAULT 0,
  quantite_commandee numeric DEFAULT 0,
  transporteur text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.livraisons_commande TO authenticated;
GRANT ALL ON public.livraisons_commande TO service_role;
ALTER TABLE public.livraisons_commande ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "livraisons_commande_all_authenticated" ON public.livraisons_commande;
CREATE POLICY "livraisons_commande_all_authenticated" ON public.livraisons_commande FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "livraisons_commande_service_role" ON public.livraisons_commande;
CREATE POLICY "livraisons_commande_service_role" ON public.livraisons_commande FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_livcmd_tournee ON public.livraisons_commande(tournee_id);
CREATE INDEX IF NOT EXISTS idx_livcmd_commande ON public.livraisons_commande(commande_id);
DROP TRIGGER IF EXISTS trg_livraisons_commande_updated_at ON public.livraisons_commande;
CREATE TRIGGER trg_livraisons_commande_updated_at BEFORE UPDATE ON public.livraisons_commande
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ---------- livsuivi_commandes (suivi par commande d'une tournée) ----------
CREATE TABLE IF NOT EXISTS public.livsuivi_commandes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commande_id uuid NOT NULL REFERENCES public.commandes(commande_id) ON DELETE CASCADE,
  tournee_id uuid REFERENCES public.tournees(tournee_id) ON DELETE SET NULL,
  type_livraison text NOT NULL DEFAULT 'direct',
  gare_depot text,
  gare_destination text,
  ville_destination text,
  livreur_nom text,
  vehicule text,
  receptionnaire_nom text,
  receptionnaire_telephone text,
  statut text NOT NULL DEFAULT 'preparee',
  derniere_maj timestamptz NOT NULL DEFAULT now(),
  cloturee boolean NOT NULL DEFAULT false,
  ordre_passage integer,
  point_livraison text,
  heure_depart timestamptz,
  heure_arrivee timestamptz,
  heure_livraison timestamptz,
  signature_url text,
  photo_preuve_url text,
  commentaire_reception text,
  retour_motif text,
  nb_cartons integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.livsuivi_commandes TO authenticated;
GRANT ALL ON public.livsuivi_commandes TO service_role;
ALTER TABLE public.livsuivi_commandes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "livsuivi_commandes_all_authenticated" ON public.livsuivi_commandes;
CREATE POLICY "livsuivi_commandes_all_authenticated" ON public.livsuivi_commandes FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "livsuivi_commandes_service_role" ON public.livsuivi_commandes;
CREATE POLICY "livsuivi_commandes_service_role" ON public.livsuivi_commandes FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_livsuivi_tournee ON public.livsuivi_commandes(tournee_id);
CREATE INDEX IF NOT EXISTS idx_livsuivi_commande ON public.livsuivi_commandes(commande_id);
CREATE INDEX IF NOT EXISTS idx_livsuivi_statut ON public.livsuivi_commandes(statut);
DROP TRIGGER IF EXISTS trg_livsuivi_commandes_updated_at ON public.livsuivi_commandes;
CREATE TRIGGER trg_livsuivi_commandes_updated_at BEFORE UPDATE ON public.livsuivi_commandes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ---------- livsuivi_historique ----------
CREATE TABLE IF NOT EXISTS public.livsuivi_historique (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  livraison_id uuid NOT NULL REFERENCES public.livsuivi_commandes(id) ON DELETE CASCADE,
  etape text NOT NULL,
  commentaire text,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  user_id uuid,
  user_nom text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.livsuivi_historique TO authenticated;
GRANT ALL ON public.livsuivi_historique TO service_role;
ALTER TABLE public.livsuivi_historique ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "livsuivi_historique_all_authenticated" ON public.livsuivi_historique;
CREATE POLICY "livsuivi_historique_all_authenticated" ON public.livsuivi_historique FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "livsuivi_historique_service_role" ON public.livsuivi_historique;
CREATE POLICY "livsuivi_historique_service_role" ON public.livsuivi_historique FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_livhist_livraison ON public.livsuivi_historique(livraison_id);
CREATE INDEX IF NOT EXISTS idx_livhist_created ON public.livsuivi_historique(created_at);

-- =========================================================
-- RPCs
-- =========================================================

-- finaliser_tournee : passe la tournée à en_cours et crée les lignes livsuivi_commandes
CREATE OR REPLACE FUNCTION public.finaliser_tournee(_tournee_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_type text; v_statut text;
BEGIN
  SELECT type_tournee, statut INTO v_type, v_statut
  FROM public.tournees WHERE tournee_id = _tournee_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Tournée introuvable'; END IF;
  IF v_statut NOT IN ('preparee','brouillon') THEN
    RAISE EXCEPTION 'Tournée déjà validée (statut=%)', v_statut;
  END IF;

  INSERT INTO public.livsuivi_commandes(commande_id, tournee_id, type_livraison, ville_destination, livreur_nom, vehicule, statut, nb_cartons)
  SELECT DISTINCT c.commande_id, _tournee_id,
    COALESCE(v_type,'direct'),
    COALESCE(col.ville_livraison, col.ville_destination),
    col.livreur_nom, col.vehicule, 'preparee', col.nb_cartons
  FROM public.colis col
  JOIN public.commandes c ON c.commande_id = col.commande_id
  WHERE col.tournee_id = _tournee_id
    AND NOT EXISTS (
      SELECT 1 FROM public.livsuivi_commandes ls
      WHERE ls.tournee_id = _tournee_id AND ls.commande_id = col.commande_id
    );

  UPDATE public.tournees SET statut = 'en_cours' WHERE tournee_id = _tournee_id;
  RETURN jsonb_build_object('tournee_id', _tournee_id, 'statut', 'en_cours');
END;$$;

GRANT EXECUTE ON FUNCTION public.finaliser_tournee(uuid) TO authenticated;

-- livsuivi_avancer
CREATE OR REPLACE FUNCTION public.livsuivi_avancer(
  _livraison_id uuid, _etape text, _meta jsonb DEFAULT '{}'::jsonb, _commentaire text DEFAULT NULL
) RETURNS public.livsuivi_commandes LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.livsuivi_commandes; v_email text;
BEGIN
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
END;$$;

GRANT EXECUTE ON FUNCTION public.livsuivi_avancer(uuid,text,jsonb,text) TO authenticated;

-- livsuivi_avancer_masse
CREATE OR REPLACE FUNCTION public.livsuivi_avancer_masse(
  _tournee_id uuid, _etape text, _meta jsonb DEFAULT '{}'::jsonb, _filtre_gare text DEFAULT NULL
) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; n integer := 0;
BEGIN
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
END;$$;

GRANT EXECUTE ON FUNCTION public.livsuivi_avancer_masse(uuid,text,jsonb,text) TO authenticated;

-- livsuivi_confirmer_reception
CREATE OR REPLACE FUNCTION public.livsuivi_confirmer_reception(
  _id uuid, _signature_url text DEFAULT NULL, _photo_url text DEFAULT NULL,
  _receptionnaire_nom text DEFAULT NULL, _receptionnaire_tel text DEFAULT NULL,
  _commentaire text DEFAULT NULL
) RETURNS public.livsuivi_commandes LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.livsuivi_commandes; v_tournee uuid; v_reste int;
BEGIN
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
END;$$;

GRANT EXECUTE ON FUNCTION public.livsuivi_confirmer_reception(uuid,text,text,text,text,text) TO authenticated;

-- supprimer_livraison_suivi
CREATE OR REPLACE FUNCTION public.supprimer_livraison_suivi(_id uuid, _motif text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.livsuivi_commandes; v_hist int;
BEGIN
  SELECT * INTO v_row FROM public.livsuivi_commandes WHERE id = _id;
  IF v_row.id IS NULL THEN RETURN NULL; END IF;
  SELECT count(*) INTO v_hist FROM public.livsuivi_historique WHERE livraison_id = _id;
  DELETE FROM public.livsuivi_commandes WHERE id = _id;
  RETURN jsonb_build_object(
    'livraison_id', _id,
    'commande_id', v_row.commande_id,
    'bl_id', NULL,
    'motif', _motif,
    'historique_supprime', v_hist,
    'colis_reinitialises', 0,
    'livraisons_detachees', 0,
    'livraisons_commande_detachees', 0,
    'notifications_supprimees', 0,
    'role', CASE WHEN public.has_role(auth.uid(),'super_admin') THEN 'super_admin' ELSE 'user' END
  );
END;$$;

GRANT EXECUTE ON FUNCTION public.supprimer_livraison_suivi(uuid,text) TO authenticated;
