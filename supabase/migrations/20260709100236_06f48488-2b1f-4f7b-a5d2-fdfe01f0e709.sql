
-- Helper: finance / accounting access
CREATE OR REPLACE FUNCTION public.has_finance_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role = ANY (ARRAY[
        'super_admin'::app_role,
        'directeur_general'::app_role,
        'comptable'::app_role,
        'assistante_comptable'::app_role,
        'directeur_commercial'::app_role
      ])
  )
$$;

-- Helper: commercial access
CREATE OR REPLACE FUNCTION public.has_commercial_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role = ANY (ARRAY[
        'super_admin'::app_role,
        'directeur_general'::app_role,
        'directeur_commercial'::app_role,
        'comptable'::app_role,
        'secretariat'::app_role,
        'assistante'::app_role
      ])
  )
$$;

REVOKE ALL ON FUNCTION public.has_finance_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_finance_access(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.has_commercial_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_commercial_access(uuid) TO authenticated, service_role;

-- 1) colis_lignes → align with colis (has_operational_access)
DROP POLICY IF EXISTS "staff read colis_lignes"  ON public.colis_lignes;
DROP POLICY IF EXISTS "staff write colis_lignes" ON public.colis_lignes;
CREATE POLICY "operational read colis_lignes" ON public.colis_lignes
  FOR SELECT TO authenticated
  USING (public.has_operational_access(auth.uid()));
CREATE POLICY "operational write colis_lignes" ON public.colis_lignes
  FOR ALL TO authenticated
  USING (public.has_operational_access(auth.uid()))
  WITH CHECK (public.has_operational_access(auth.uid()));

-- 2) Finance tables → has_finance_access
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['fournisseurs','achats','transactions','avoirs','fne_factures']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff read '||t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff write '||t, t);
    EXECUTE format($f$CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.has_finance_access(auth.uid()))$f$, 'finance read '||t, t);
    EXECUTE format($f$CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public.has_finance_access(auth.uid())) WITH CHECK (public.has_finance_access(auth.uid()))$f$, 'finance write '||t, t);
  END LOOP;
END $$;

-- 3) Logistics/operational tables → has_operational_access
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['incidents','specimens','transferts','ordres_colisage','expeditions']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff read '||t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff write '||t, t);
    EXECUTE format($f$CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.has_operational_access(auth.uid()))$f$, 'operational read '||t, t);
    EXECUTE format($f$CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public.has_operational_access(auth.uid())) WITH CHECK (public.has_operational_access(auth.uid()))$f$, 'operational write '||t, t);
  END LOOP;
END $$;

-- 4) Commercial tables → has_commercial_access
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['proformas','retours']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff read '||t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff write '||t, t);
    EXECUTE format($f$CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.has_commercial_access(auth.uid()))$f$, 'commercial read '||t, t);
    EXECUTE format($f$CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public.has_commercial_access(auth.uid())) WITH CHECK (public.has_commercial_access(auth.uid()))$f$, 'commercial write '||t, t);
  END LOOP;
END $$;

-- 5) documents: split SELECT to match the write split (operational vs sensitive)
DROP POLICY IF EXISTS "staff read documents" ON public.documents;
CREATE POLICY "documents_read_operational" ON public.documents
  FOR SELECT TO authenticated
  USING (
    public.has_operational_access(auth.uid())
    AND type_document <> ALL (ARRAY['finance','comptabilite','paie','rh','contrat','bulletin','fiscal'])
  );
CREATE POLICY "documents_read_sensitive" ON public.documents
  FOR SELECT TO authenticated
  USING (
    type_document = ANY (ARRAY['finance','comptabilite','paie','rh','contrat','bulletin','fiscal'])
    AND public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role,'directeur_general'::app_role,'comptable'::app_role])
  );

-- 6) trigger_execution_log → admin/direction only
DO $$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='trigger_execution_log'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.trigger_execution_log', p.policyname);
  END LOOP;
END $$;

CREATE POLICY "admin read trigger_execution_log" ON public.trigger_execution_log
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role,'directeur_general'::app_role]));
