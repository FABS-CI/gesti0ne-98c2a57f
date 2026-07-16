
-- ============================================================
-- 1. bons_livraison : rename + colonnes manquantes
-- ============================================================
ALTER TABLE public.bons_livraison RENAME COLUMN bon_id TO bl_id;

ALTER TABLE public.bons_livraison
  ADD COLUMN IF NOT EXISTS date_emission date DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS date_livraison date,
  ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'a_preparer',
  ADD COLUMN IF NOT EXISTS client_id uuid,
  ADD COLUMN IF NOT EXISTS exercice_id uuid;

UPDATE public.bons_livraison SET date_emission = date_bon WHERE date_emission IS NULL AND date_bon IS NOT NULL;

-- ============================================================
-- 2. colis
-- ============================================================
CREATE TABLE IF NOT EXISTS public.colis (
  colis_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bl_id uuid NOT NULL REFERENCES public.bons_livraison(bl_id) ON DELETE CASCADE,
  tournee_id uuid,
  reference text,
  numero_carton integer,
  nb_cartons integer,
  destinataire text,
  responsable_id uuid,
  responsable_nom text,
  mode_acheminement text,
  livreur_nom text,
  livreur_telephone text,
  vehicule text,
  quartier text,
  commune text,
  ville_livraison text,
  gare_depart text,
  ville_destination text,
  gare_responsable text,
  gare_telephone text,
  poids numeric DEFAULT 0,
  observations text,
  statut text NOT NULL DEFAULT 'a_livrer',
  date_colisage timestamptz DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.colis TO authenticated;
GRANT ALL ON public.colis TO service_role;
GRANT SELECT ON public.colis TO anon;

ALTER TABLE public.colis ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_read_colis" ON public.colis FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_write_colis" ON public.colis FOR ALL TO authenticated
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_colis_bl ON public.colis(bl_id);
CREATE INDEX IF NOT EXISTS idx_colis_tournee ON public.colis(tournee_id);

CREATE TRIGGER update_colis_updated_at BEFORE UPDATE ON public.colis
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- 3. colis_lignes
-- ============================================================
CREATE TABLE IF NOT EXISTS public.colis_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  colis_id uuid NOT NULL REFERENCES public.colis(colis_id) ON DELETE CASCADE,
  produit_id uuid,
  designation text,
  reference_produit text,
  quantite numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.colis_lignes TO authenticated;
GRANT ALL ON public.colis_lignes TO service_role;
ALTER TABLE public.colis_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_read_colis_lignes" ON public.colis_lignes FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_write_colis_lignes" ON public.colis_lignes FOR ALL TO authenticated
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_colis_lignes_colis ON public.colis_lignes(colis_id);

-- ============================================================
-- 4. colis_statut_historique
-- ============================================================
CREATE TABLE IF NOT EXISTS public.colis_statut_historique (
  historique_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  colis_id uuid REFERENCES public.colis(colis_id) ON DELETE CASCADE,
  bl_id uuid,
  ancien_statut text,
  nouveau_statut text,
  motif text,
  user_id uuid,
  user_nom text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.colis_statut_historique TO authenticated;
GRANT ALL ON public.colis_statut_historique TO service_role;
ALTER TABLE public.colis_statut_historique ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_read_colis_hist" ON public.colis_statut_historique FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_write_colis_hist" ON public.colis_statut_historique FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================================
-- 5. colisage_responsables
-- ============================================================
CREATE TABLE IF NOT EXISTS public.colisage_responsables (
  responsable_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid NOT NULL REFERENCES public.employes(employe_id) ON DELETE CASCADE,
  depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  actif boolean NOT NULL DEFAULT true,
  date_affectation timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (employe_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.colisage_responsables TO authenticated;
GRANT ALL ON public.colisage_responsables TO service_role;
ALTER TABLE public.colisage_responsables ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_read_colisage_resp" ON public.colisage_responsables FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_write_colisage_resp" ON public.colisage_responsables FOR ALL TO authenticated
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

CREATE TRIGGER update_colisage_responsables_updated_at BEFORE UPDATE ON public.colisage_responsables
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- 6. v_colisage_responsables
-- ============================================================
CREATE OR REPLACE VIEW public.v_colisage_responsables
WITH (security_invoker=on) AS
SELECT
  r.responsable_id,
  r.employe_id,
  e.matricule,
  e.nom_complet,
  e.poste,
  e.telephone,
  r.depot_id,
  d.nom AS depot_nom,
  r.actif,
  r.date_affectation
FROM public.colisage_responsables r
JOIN public.employes e ON e.employe_id = r.employe_id
LEFT JOIN public.depots d ON d.depot_id = r.depot_id;

GRANT SELECT ON public.v_colisage_responsables TO authenticated;

-- ============================================================
-- 7. RPCs colisage
-- ============================================================
CREATE OR REPLACE FUNCTION public.creer_colisage(_bl_id uuid, _payload jsonb)
RETURNS SETOF public.colis
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nb integer := COALESCE((_payload->>'nb_cartons')::int, 1);
  i integer;
  v_ref text;
  v_bl_ref text;
BEGIN
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  SELECT reference INTO v_bl_ref FROM public.bons_livraison WHERE bl_id = _bl_id;

  FOR i IN 1..v_nb LOOP
    v_ref := COALESCE(v_bl_ref, 'BL') || '-C' || lpad(i::text, 3, '0');
    INSERT INTO public.colis(
      bl_id, reference, numero_carton, nb_cartons,
      responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule,
      quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone,
      observations, date_colisage
    ) VALUES (
      _bl_id, v_ref, i, v_nb,
      _payload->>'responsable_nom', _payload->>'mode_acheminement',
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      _payload->>'observations',
      COALESCE((_payload->>'date_colisage')::timestamptz, now())
    );
  END LOOP;

  UPDATE public.bons_livraison SET statut = 'colisage_termine' WHERE bl_id = _bl_id;
  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END;
$$;

CREATE OR REPLACE FUNCTION public.creer_colisage_manuel(_bl_id uuid, _payload jsonb, _cartons jsonb)
RETURNS SETOF public.colis
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_carton jsonb;
  v_ligne jsonb;
  v_colis_id uuid;
  v_ref text;
  v_bl_ref text;
  v_num integer := 0;
  v_nb integer := jsonb_array_length(_cartons);
BEGIN
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  SELECT reference INTO v_bl_ref FROM public.bons_livraison WHERE bl_id = _bl_id;

  FOR v_carton IN SELECT * FROM jsonb_array_elements(_cartons) LOOP
    v_num := v_num + 1;
    v_ref := COALESCE(v_bl_ref, 'BL') || '-C' || lpad(v_num::text, 3, '0');
    INSERT INTO public.colis(
      bl_id, reference, numero_carton, nb_cartons,
      responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule,
      quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone,
      poids, observations, date_colisage
    ) VALUES (
      _bl_id, v_ref, v_num, v_nb,
      _payload->>'responsable_nom', _payload->>'mode_acheminement',
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      COALESCE((v_carton->>'poids')::numeric, 0),
      COALESCE(v_carton->>'observations', _payload->>'observations'),
      COALESCE((_payload->>'date_colisage')::timestamptz, now())
    ) RETURNING colis_id INTO v_colis_id;

    FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_carton->'lignes') LOOP
      INSERT INTO public.colis_lignes(colis_id, produit_id, designation, reference_produit, quantite)
      VALUES (
        v_colis_id,
        NULLIF(v_ligne->>'produit_id','')::uuid,
        v_ligne->>'designation',
        v_ligne->>'reference_produit',
        COALESCE((v_ligne->>'quantite')::numeric, 0)
      );
    END LOOP;
  END LOOP;

  UPDATE public.bons_livraison SET statut = 'colisage_termine' WHERE bl_id = _bl_id;
  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END;
$$;

CREATE OR REPLACE FUNCTION public.modifier_colis_lignes(_colis_id uuid, _lignes jsonb, _motif text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ligne jsonb;
BEGIN
  DELETE FROM public.colis_lignes WHERE colis_id = _colis_id;
  FOR v_ligne IN SELECT * FROM jsonb_array_elements(_lignes) LOOP
    INSERT INTO public.colis_lignes(colis_id, produit_id, designation, reference_produit, quantite)
    VALUES (
      _colis_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      v_ligne->>'designation',
      v_ligne->>'reference_produit',
      COALESCE((v_ligne->>'quantite')::numeric, 0)
    );
  END LOOP;

  INSERT INTO public.colis_statut_historique(colis_id, ancien_statut, nouveau_statut, motif, user_id)
  VALUES (_colis_id, 'modifie', 'modifie', _motif, auth.uid());
END;
$$;

CREATE OR REPLACE FUNCTION public.annuler_colisage(_bl_id uuid, _motif text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.colis_statut_historique(bl_id, ancien_statut, nouveau_statut, motif, user_id)
  SELECT _bl_id, 'colisage_termine', 'annule', _motif, auth.uid();
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  UPDATE public.bons_livraison SET statut = 'a_preparer' WHERE bl_id = _bl_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.supprimer_colisage(_bl_id uuid, _motif text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ref text;
  v_count int;
BEGIN
  SELECT reference INTO v_ref FROM public.bons_livraison WHERE bl_id = _bl_id;
  SELECT COUNT(*) INTO v_count FROM public.colis WHERE bl_id = _bl_id;
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  UPDATE public.bons_livraison SET statut = 'a_preparer' WHERE bl_id = _bl_id;

  RETURN jsonb_build_object(
    'bl_id', _bl_id,
    'reference', v_ref,
    'motif', _motif,
    'colis_supprimes', v_count,
    'notifications_supprimees', 0,
    'envois_supprimes', 0,
    'livsuivi_supprimes', 0,
    'livraisons_detachees', 0,
    'livraisons_commande_detachees', 0,
    'expeditions_detachees', 0,
    'tournees_recalculees', 0,
    'role', CASE WHEN public.has_role(auth.uid(),'super_admin') THEN 'super_admin' ELSE 'user' END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.deverrouiller_colisage(_bl_id uuid, _motif text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.bons_livraison SET statut = 'colisage_en_cours' WHERE bl_id = _bl_id;
  INSERT INTO public.colis_statut_historique(bl_id, ancien_statut, nouveau_statut, motif, user_id)
  VALUES (_bl_id, 'colisage_termine', 'colisage_en_cours', _motif, auth.uid());
END;
$$;

CREATE OR REPLACE FUNCTION public.get_carton_public(_colis_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'colis_id', c.colis_id,
    'reference_colis', c.reference,
    'numero_carton', c.numero_carton,
    'nb_cartons', c.nb_cartons,
    'bl_reference', bl.reference,
    'bl_statut', bl.statut,
    'commande_reference', cmd.reference,
    'client_nom', COALESCE(cmd.client_nom, bl.client_nom),
    'etablissement', cmd.etablissement,
    'destinataire', c.destinataire,
    'telephone', cmd.telephone,
    'adresse', cmd.adresse,
    'ville', cmd.ville,
    'destination', COALESCE(c.ville_livraison, c.ville_destination),
    'mode_acheminement', c.mode_acheminement,
    'statut_logistique', c.statut,
    'date_colisage', c.date_colisage,
    'preparateur', c.responsable_nom,
    'observations', c.observations,
    'produits', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('designation', cl.designation, 'quantite', cl.quantite))
      FROM public.colis_lignes cl WHERE cl.colis_id = c.colis_id
    ), '[]'::jsonb)
  )
  FROM public.colis c
  LEFT JOIN public.bons_livraison bl ON bl.bl_id = c.bl_id
  LEFT JOIN public.commandes cmd ON cmd.commande_id = bl.commande_id
  WHERE c.colis_id = _colis_id;
$$;

GRANT EXECUTE ON FUNCTION public.creer_colisage(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.creer_colisage_manuel(uuid, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.modifier_colis_lignes(uuid, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.annuler_colisage(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supprimer_colisage(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deverrouiller_colisage(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_carton_public(uuid) TO anon, authenticated;
