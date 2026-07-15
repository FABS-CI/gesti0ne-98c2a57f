
-- Enum des rôles applicatifs
CREATE TYPE public.app_role AS ENUM (
  'super_admin',
  'directeur_general',
  'comptable',
  'directeur_commercial',
  'gestionnaire_stock',
  'responsable_magasinier',
  'secretariat',
  'assistante',
  'service_logistique'
);

-- Table des rôles utilisateurs (rôles historiques)
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Fonction security definer pour vérifier un rôle sans récursion RLS
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

CREATE POLICY "Users can read their own roles"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Super admins can read all roles"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'));

-- Tables RBAC v2 minimales (vides) pour éviter les erreurs 404 côté client
CREATE TABLE public.rbac_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  libelle TEXT NOT NULL,
  actif BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.rbac_roles TO authenticated;
GRANT ALL ON public.rbac_roles TO service_role;
ALTER TABLE public.rbac_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read rbac_roles"
  ON public.rbac_roles FOR SELECT TO authenticated USING (true);

CREATE TABLE public.rbac_user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rbac_role_id UUID NOT NULL REFERENCES public.rbac_roles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, rbac_role_id)
);
GRANT SELECT ON public.rbac_user_roles TO authenticated;
GRANT ALL ON public.rbac_user_roles TO service_role;
ALTER TABLE public.rbac_user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own rbac assignments"
  ON public.rbac_user_roles FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Stub de la RPC list_user_permissions : retourne 0 ligne
-- (le bypass super_admin dans usePermissions couvrira les droits)
CREATE OR REPLACE FUNCTION public.list_user_permissions(_user_id UUID)
RETURNS TABLE (permission_code TEXT)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NULL::TEXT WHERE false;
$$;

GRANT EXECUTE ON FUNCTION public.list_user_permissions(UUID) TO authenticated;

-- Attribuer super_admin à tous les comptes existants pour débloquer l'app
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'super_admin'::public.app_role FROM auth.users
ON CONFLICT DO NOTHING;
