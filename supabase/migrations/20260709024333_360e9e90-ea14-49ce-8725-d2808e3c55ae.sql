
-- 1) Tighten employes PII read: remove comptable from broad PII access
DROP POLICY IF EXISTS "rh read employes" ON public.employes;
CREATE POLICY "rh read employes"
ON public.employes FOR SELECT
USING (public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role]));

-- 2) Introduce module-scoped access helpers to replace broad is_staff() on sensitive tables
CREATE OR REPLACE FUNCTION public.has_commercial_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role = ANY (ARRAY[
        'super_admin'::app_role,
        'directeur_general'::app_role,
        'directeur_commercial'::app_role,
        'comptable'::app_role,
        'assistante_comptable'::app_role,
        'secretariat'::app_role,
        'assistante'::app_role
      ])
  )
$$;

CREATE OR REPLACE FUNCTION public.has_operational_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role = ANY (ARRAY[
        'super_admin'::app_role,
        'directeur_general'::app_role,
        'service_logistique'::app_role,
        'responsable_magasinier'::app_role,
        'gestionnaire_stock'::app_role,
        'directeur_commercial'::app_role,
        'secretariat'::app_role
      ])
  )
$$;

-- 3) Commercial/finance tables — restrict to commercial roles only
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['clients','commandes','factures','paiements'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff read ' || t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff write ' || t, t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_commercial_access(auth.uid()))', 'commercial read ' || t, t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL USING (public.has_commercial_access(auth.uid())) WITH CHECK (public.has_commercial_access(auth.uid()))', 'commercial write ' || t, t);
  END LOOP;
END $$;

-- 4) Operational / realtime-published tables — restrict to operational roles
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['colis','bons_livraison','produits','stocks_depots','stock_mouvements'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff read ' || t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'staff write ' || t, t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_operational_access(auth.uid()))', 'operational read ' || t, t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL USING (public.has_operational_access(auth.uid())) WITH CHECK (public.has_operational_access(auth.uid()))', 'operational write ' || t, t);
  END LOOP;
END $$;

-- 5) tournees SELECT — tighten from is_staff to operational
DROP POLICY IF EXISTS "Staff can view tournees" ON public.tournees;
CREATE POLICY "Operational can view tournees"
ON public.tournees FOR SELECT
USING (public.has_operational_access(auth.uid()));
