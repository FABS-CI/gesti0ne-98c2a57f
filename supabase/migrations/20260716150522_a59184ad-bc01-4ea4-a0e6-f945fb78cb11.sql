
-- 1) Fix paiement_annulations_audit permissive policies
DROP POLICY IF EXISTS "paa read auth" ON public.paiement_annulations_audit;
DROP POLICY IF EXISTS "paa write auth" ON public.paiement_annulations_audit;

-- 2) Convert SECURITY DEFINER views to SECURITY INVOKER
ALTER VIEW public.parametres SET (security_invoker = on);
ALTER VIEW public.incidents SET (security_invoker = on);
ALTER VIEW public.paie_rubriques SET (security_invoker = on);
ALTER VIEW public.paie_parametres SET (security_invoker = on);
ALTER VIEW public.bons_retour SET (security_invoker = on);
ALTER VIEW public.exercices SET (security_invoker = on);
ALTER VIEW public.v_rpc_errors_recent SET (security_invoker = on);

-- 3) Revoke EXECUTE on all public SECURITY DEFINER functions from anon and PUBLIC
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef = true
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM PUBLIC, anon;', r.proname, r.args);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated, service_role;', r.proname, r.args);
  END LOOP;
END $$;
