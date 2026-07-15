-- Sécurité: retirer EXECUTE public/anon sur toutes les fonctions SECURITY DEFINER du schéma public.
-- Elles restent appelables par les utilisateurs authentifiés (chaque fonction fait sa propre vérif de rôle via has_role).
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name,
           p.proname AS func_name,
           pg_get_function_identity_arguments(p.oid) AS args
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.prosecdef = true
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC, anon;',
                   r.schema_name, r.func_name, r.args);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated, service_role;',
                   r.schema_name, r.func_name, r.args);
  END LOOP;
END $$;

-- Refuser par défaut sur les futures fonctions créées dans public.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;