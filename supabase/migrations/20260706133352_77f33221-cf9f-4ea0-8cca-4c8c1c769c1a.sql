-- Optimisation RLS: envelopper is_staff(auth.uid()) dans (SELECT ...) 
-- pour que Postgres l'évalue une seule fois par requête (initPlan) 
-- au lieu d'une fois par ligne. Impact majeur sur les tables > 100 lignes.

DO $$
DECLARE
  r RECORD;
  new_qual TEXT;
  new_check TEXT;
BEGIN
  FOR r IN
    SELECT
      n.nspname AS schema_name,
      c.relname AS table_name,
      p.polname,
      p.polcmd,
      pg_get_expr(p.polqual, p.polrelid) AS qual,
      pg_get_expr(p.polwithcheck, p.polrelid) AS wcheck
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND (
        (pg_get_expr(p.polqual, p.polrelid) ~ 'is_staff\(auth\.uid\(\)\)'
          AND pg_get_expr(p.polqual, p.polrelid) !~ 'SELECT is_staff')
        OR
        (pg_get_expr(p.polwithcheck, p.polrelid) ~ 'is_staff\(auth\.uid\(\)\)'
          AND pg_get_expr(p.polwithcheck, p.polrelid) !~ 'SELECT is_staff')
      )
  LOOP
    new_qual := regexp_replace(
      COALESCE(r.qual, ''),
      'is_staff\(auth\.uid\(\)\)',
      '(SELECT public.is_staff((SELECT auth.uid())))',
      'g'
    );
    new_check := regexp_replace(
      COALESCE(r.wcheck, ''),
      'is_staff\(auth\.uid\(\)\)',
      '(SELECT public.is_staff((SELECT auth.uid())))',
      'g'
    );

    IF r.qual IS NOT NULL AND r.wcheck IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I USING (%s) WITH CHECK (%s)',
        r.polname, r.schema_name, r.table_name, new_qual, new_check
      );
    ELSIF r.qual IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I USING (%s)',
        r.polname, r.schema_name, r.table_name, new_qual
      );
    ELSIF r.wcheck IS NOT NULL THEN
      EXECUTE format(
        'ALTER POLICY %I ON %I.%I WITH CHECK (%s)',
        r.polname, r.schema_name, r.table_name, new_check
      );
    END IF;
  END LOOP;
END $$;