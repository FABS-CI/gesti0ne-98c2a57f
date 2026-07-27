-- =====================================================================
-- LOT 1 : Périmètre (service / département / dépôts) + fiche utilisateur
-- =====================================================================

-- 1. Services internes -------------------------------------------------
CREATE TABLE IF NOT EXISTS public.services (
  service_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  libelle text NOT NULL,
  departement_id uuid REFERENCES public.departements(departement_id) ON DELETE SET NULL,
  responsable text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.services TO authenticated;
GRANT ALL ON public.services TO service_role;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "services read" ON public.services;
CREATE POLICY "services read" ON public.services
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "services write" ON public.services;
CREATE POLICY "services write" ON public.services
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

DROP TRIGGER IF EXISTS trg_services_updated ON public.services;
CREATE TRIGGER trg_services_updated BEFORE UPDATE ON public.services
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Services de base alignés sur les rôles métier de l'ERP
INSERT INTO public.services (code, libelle) VALUES
  ('direction',    'Direction Générale'),
  ('commercial',   'Commercial'),
  ('comptabilite', 'Comptabilité'),
  ('logistique',   'Logistique'),
  ('magasin',      'Magasin / Stocks'),
  ('rh',           'Ressources Humaines'),
  ('secretariat',  'Secrétariat'),
  ('informatique', 'Informatique')
ON CONFLICT (code) DO NOTHING;

-- 2. Fiche utilisateur enrichie ---------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS matricule text,
  ADD COLUMN IF NOT EXISTS nom text,
  ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'actif',
  ADD COLUMN IF NOT EXISTS locked_at timestamptz,
  ADD COLUMN IF NOT EXISTS locked_reason text,
  ADD COLUMN IF NOT EXISTS service_id uuid REFERENCES public.services(service_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS departement_id uuid REFERENCES public.departements(departement_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS depot_principal_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS derniere_connexion timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_matricule_key
  ON public.profiles (matricule) WHERE matricule IS NOT NULL;

-- statut : validation par trigger (règle métier évolutive)
CREATE OR REPLACE FUNCTION public.trg_profiles_validate_statut()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.statut NOT IN ('actif','suspendu','verrouille') THEN
    RAISE EXCEPTION 'Statut utilisateur invalide: %', NEW.statut;
  END IF;
  IF NEW.statut = 'actif' THEN
    NEW.locked_at := NULL;
    NEW.locked_reason := NULL;
  ELSIF (TG_OP = 'INSERT' OR OLD.statut IS DISTINCT FROM NEW.statut) AND NEW.locked_at IS NULL THEN
    NEW.locked_at := now();
  END IF;
  NEW.actif := (NEW.statut = 'actif');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_statut ON public.profiles;
CREATE TRIGGER trg_profiles_statut BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.trg_profiles_validate_statut();

-- alignement initial statut <- actif
UPDATE public.profiles SET statut = CASE WHEN actif THEN 'actif' ELSE 'suspendu' END;

-- 3. Rattachement multi-dépôts ----------------------------------------
CREATE TABLE IF NOT EXISTS public.user_depots (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  depot_id uuid NOT NULL REFERENCES public.depots(depot_id) ON DELETE CASCADE,
  principal boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, depot_id)
);
CREATE INDEX IF NOT EXISTS idx_user_depots_user ON public.user_depots(user_id);
CREATE INDEX IF NOT EXISTS idx_user_depots_depot ON public.user_depots(depot_id);

GRANT SELECT ON public.user_depots TO authenticated;
GRANT ALL ON public.user_depots TO service_role;
ALTER TABLE public.user_depots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_depots self read" ON public.user_depots;
CREATE POLICY "user_depots self read" ON public.user_depots
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'::app_role));

DROP POLICY IF EXISTS "user_depots write" ON public.user_depots;
CREATE POLICY "user_depots write" ON public.user_depots
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

-- 4. Fonctions de périmètre -------------------------------------------
-- Seul le Super Administrateur a une portée globale.
CREATE OR REPLACE FUNCTION public.is_global_scope(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rbac2_user_roles
    WHERE user_id = _user_id AND role_code = 'super_admin'
  ) OR EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = 'super_admin'::app_role
  );
$$;

CREATE OR REPLACE FUNCTION public.user_service_id(_user_id uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT service_id FROM public.profiles WHERE id = _user_id;
$$;

CREATE OR REPLACE FUNCTION public.user_departement_id(_user_id uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT departement_id FROM public.profiles WHERE id = _user_id;
$$;

CREATE OR REPLACE FUNCTION public.user_depot_ids(_user_id uuid)
RETURNS uuid[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    array_agg(DISTINCT d) FILTER (WHERE d IS NOT NULL),
    '{}'::uuid[]
  )
  FROM (
    SELECT depot_id AS d FROM public.user_depots WHERE user_id = _user_id
    UNION
    SELECT depot_principal_id FROM public.profiles WHERE id = _user_id
  ) s;
$$;

-- Vrai si l'utilisateur peut agir sur ce dépôt (global, rattaché,
-- ou aucun rattachement défini => pas de restriction dépôt).
CREATE OR REPLACE FUNCTION public.can_access_depot(_user_id uuid, _depot_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_global_scope(_user_id)
      OR _depot_id IS NULL
      OR cardinality(public.user_depot_ids(_user_id)) = 0
      OR _depot_id = ANY (public.user_depot_ids(_user_id));
$$;

CREATE OR REPLACE FUNCTION public.can_access_service(_user_id uuid, _service_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_global_scope(_user_id)
      OR _service_id IS NULL
      OR public.user_service_id(_user_id) IS NULL
      OR _service_id = public.user_service_id(_user_id);
$$;

GRANT EXECUTE ON FUNCTION public.is_global_scope(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_service_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_departement_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_depot_ids(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_depot(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_service(uuid, uuid) TO authenticated;

-- 5. Nettoyage des rôles jamais attribués ------------------------------
DELETE FROM public.rbac2_roles
WHERE code IN ('auditeur','caissier','employe','livreur','manager')
  AND NOT EXISTS (
    SELECT 1 FROM public.rbac2_user_roles ur WHERE ur.role_code = rbac2_roles.code
  );