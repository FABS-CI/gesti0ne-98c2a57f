-- =====================================================================
-- Lot R4-bis / Étape 1 : fonction pont lisant UNIQUEMENT le registre v2
-- =====================================================================
CREATE OR REPLACE FUNCTION public.has_role_compat(_user_id uuid, _role text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.rbac2_user_roles ur
    JOIN public.rbac2_roles r ON r.code = ur.role_code
    WHERE ur.user_id = _user_id
      AND ur.role_code = _role
      AND coalesce(r.statut, 'actif') NOT IN ('archive', 'inactif')
  );
$$;

REVOKE ALL ON FUNCTION public.has_role_compat(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_role_compat(uuid, text) TO authenticated, service_role;

-- =====================================================================
-- Lot R4-bis / Étape 2 : réécriture de toutes les policies utilisant
-- has_role(..., 'super_admin'::app_role) -> has_role_compat(..., 'super_admin')
-- =====================================================================
DO $do$
DECLARE
  p RECORD;
  new_qual text;
  new_check text;
  stmt text;
  cmd_txt text;
  n int := 0;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname, permissive, cmd,
           array_to_string(roles, ', ') AS roles_txt, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND coalesce(qual, '') || coalesce(with_check, '') LIKE '%has_role(%'
    ORDER BY tablename, policyname
  LOOP
    new_qual  := replace(coalesce(p.qual, ''),
                         'has_role(auth.uid(), ''super_admin''::app_role)',
                         'has_role_compat(auth.uid(), ''super_admin'')');
    new_check := replace(coalesce(p.with_check, ''),
                         'has_role(auth.uid(), ''super_admin''::app_role)',
                         'has_role_compat(auth.uid(), ''super_admin'')');

    -- Garde-fou : si une occurrence has_role( subsiste (autre rôle), on saute.
    IF new_qual LIKE '%has_role(%' OR new_check LIKE '%has_role(%' THEN
      RAISE NOTICE 'Policy ignorée (rôle non super_admin) : %.%', p.tablename, p.policyname;
      CONTINUE;
    END IF;

    cmd_txt := CASE p.cmd WHEN '*' THEN 'ALL' ELSE p.cmd END;

    EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, p.tablename);

    stmt := format('CREATE POLICY %I ON public.%I AS %s FOR %s TO %s',
                   p.policyname, p.tablename,
                   CASE WHEN p.permissive = 'PERMISSIVE' THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END,
                   cmd_txt, p.roles_txt);

    IF cmd_txt <> 'INSERT' AND p.qual IS NOT NULL THEN
      stmt := stmt || format(' USING (%s)', new_qual);
    END IF;

    IF cmd_txt IN ('INSERT', 'UPDATE', 'ALL') AND p.with_check IS NOT NULL THEN
      stmt := stmt || format(' WITH CHECK (%s)', new_check);
    END IF;

    EXECUTE stmt;
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Policies réécrites : %', n;
END
$do$;