DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT CREATE ON SCHEMA public TO service_role;

CREATE OR REPLACE FUNCTION public._exec_sql_restore(sql text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  EXECUTE sql;
END;
$$;
REVOKE ALL ON FUNCTION public._exec_sql_restore(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._exec_sql_restore(text) TO service_role;