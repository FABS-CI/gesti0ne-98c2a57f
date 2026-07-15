DO $$
DECLARE
  r record;
BEGIN
  -- Grant on all base tables in public
  FOR r IN
    SELECT tablename FROM pg_tables WHERE schemaname='public'
  LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', r.tablename);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', r.tablename);
  END LOOP;

  -- Grant SELECT on all views in public
  FOR r IN
    SELECT table_name FROM information_schema.views WHERE table_schema='public'
  LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', r.table_name);
    EXECUTE format('GRANT SELECT ON public.%I TO anon', r.table_name);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', r.table_name);
  END LOOP;

  -- Sequences (for INSERTs using default nextval)
  FOR r IN
    SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema='public'
  LOOP
    EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE public.%I TO authenticated', r.sequence_name);
    EXECUTE format('GRANT ALL ON SEQUENCE public.%I TO service_role', r.sequence_name);
  END LOOP;
END $$;

-- Ensure future tables also get the grants
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;