DROP POLICY IF EXISTS "commercial read clients" ON public.clients;
DROP POLICY IF EXISTS "commercial write clients" ON public.clients;

CREATE POLICY "clients read via rbac or commercial"
ON public.clients FOR SELECT TO authenticated
USING (
  public.has_commercial_access(auth.uid())
  OR public.has_permission_v2(auth.uid(), 'clients_dashboard.voir')
);

CREATE POLICY "clients write via commercial"
ON public.clients FOR ALL TO authenticated
USING (public.has_commercial_access(auth.uid()))
WITH CHECK (public.has_commercial_access(auth.uid()));