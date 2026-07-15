CREATE SCHEMA IF NOT EXISTS extensions;

GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

ALTER EXTENSION pg_trgm SET SCHEMA extensions;

-- Ensure the operators/functions remain resolvable to app roles without schema-qualifying calls.
ALTER DATABASE postgres SET search_path TO "$user", public, extensions;
