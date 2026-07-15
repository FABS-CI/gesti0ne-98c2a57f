
-- 1) colis_statut_historique: narrow SELECT to essential logistics roles
DROP POLICY IF EXISTS colis_statut_historique_select ON public.colis_statut_historique;
CREATE POLICY colis_statut_historique_select ON public.colis_statut_historique
  FOR SELECT TO authenticated
  USING (has_any_role(auth.uid(), ARRAY[
    'super_admin'::app_role,
    'directeur_general'::app_role,
    'service_logistique'::app_role,
    'responsable_magasinier'::app_role
  ]));

-- 2) employes: exclude soft-deleted rows from standard read policy;
-- provide a separate archive-read policy limited to super_admin / directeur_general.
DROP POLICY IF EXISTS "rh read employes" ON public.employes;
CREATE POLICY "rh read employes actifs" ON public.employes
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND has_any_role(auth.uid(), ARRAY[
      'super_admin'::app_role,
      'directeur_general'::app_role,
      'secretariat'::app_role
    ])
  );

CREATE POLICY "rh read employes archives" ON public.employes
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NOT NULL
    AND has_any_role(auth.uid(), ARRAY[
      'super_admin'::app_role,
      'directeur_general'::app_role
    ])
  );

-- 3) is_restricted_user: replace hardcoded email with a per-profile flag
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_restricted boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_profiles_is_restricted
  ON public.profiles(is_restricted) WHERE is_restricted = true;

-- Migrate the currently hardcoded email to the flag (idempotent)
UPDATE public.profiles p
   SET is_restricted = true
  FROM auth.users u
 WHERE u.id = p.id
   AND lower(u.email) = 'yakeben@editionsfabsci.com';

CREATE OR REPLACE FUNCTION public.is_restricted_user()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT p.is_restricted FROM public.profiles p WHERE p.id = auth.uid()),
    false
  );
$$;
