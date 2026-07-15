
CREATE OR REPLACE FUNCTION public.is_restricted_user()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
      AND lower(email) = ANY (ARRAY['yakeben@editionsfabsci.com'])
  );
$$;

-- Incidents
DROP POLICY IF EXISTS "deny_restricted_users_incidents" ON public.incidents;
CREATE POLICY "deny_restricted_users_incidents" ON public.incidents
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT public.is_restricted_user())
  WITH CHECK (NOT public.is_restricted_user());

DROP POLICY IF EXISTS "deny_restricted_users_incident_lignes" ON public.incident_lignes;
CREATE POLICY "deny_restricted_users_incident_lignes" ON public.incident_lignes
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT public.is_restricted_user())
  WITH CHECK (NOT public.is_restricted_user());

-- Transferts
DROP POLICY IF EXISTS "deny_restricted_users_transferts" ON public.transferts;
CREATE POLICY "deny_restricted_users_transferts" ON public.transferts
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT public.is_restricted_user())
  WITH CHECK (NOT public.is_restricted_user());

DROP POLICY IF EXISTS "deny_restricted_users_transfert_lignes" ON public.transfert_lignes;
CREATE POLICY "deny_restricted_users_transfert_lignes" ON public.transfert_lignes
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (NOT public.is_restricted_user())
  WITH CHECK (NOT public.is_restricted_user());
