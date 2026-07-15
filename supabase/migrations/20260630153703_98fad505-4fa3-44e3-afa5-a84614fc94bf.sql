
-- 1) Tighten always-true policies on public.tournees
DROP POLICY IF EXISTS "Authenticated can insert tournees" ON public.tournees;
DROP POLICY IF EXISTS "Authenticated can update tournees" ON public.tournees;
DROP POLICY IF EXISTS "Authenticated can delete tournees" ON public.tournees;

CREATE POLICY "Authenticated can insert tournees"
  ON public.tournees FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated can update tournees"
  ON public.tournees FOR UPDATE TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated can delete tournees"
  ON public.tournees FOR DELETE TO authenticated
  USING (auth.uid() IS NOT NULL);

-- 2) Revoke EXECUTE from anon on all SECURITY DEFINER functions in public schema
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname,
           pg_get_function_identity_arguments(p.oid) AS args
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prosecdef = true
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM anon, PUBLIC',
                   r.nspname, r.proname, r.args);
  END LOOP;
END $$;
