
DROP POLICY IF EXISTS "finance read fournisseurs" ON public.fournisseurs;
DROP POLICY IF EXISTS "finance write fournisseurs" ON public.fournisseurs;

CREATE POLICY "fournisseurs read via rbac or finance"
ON public.fournisseurs FOR SELECT TO authenticated
USING (
  public.has_finance_access(auth.uid())
  OR public.has_permission_v2(auth.uid(), 'fournisseurs.voir')
);

CREATE POLICY "fournisseurs insert via rbac or finance"
ON public.fournisseurs FOR INSERT TO authenticated
WITH CHECK (
  public.has_finance_access(auth.uid())
  OR public.has_permission_v2(auth.uid(), 'fournisseurs.creer')
);

CREATE POLICY "fournisseurs update via rbac or finance"
ON public.fournisseurs FOR UPDATE TO authenticated
USING (
  public.has_finance_access(auth.uid())
  OR public.has_permission_v2(auth.uid(), 'fournisseurs.modifier')
)
WITH CHECK (
  public.has_finance_access(auth.uid())
  OR public.has_permission_v2(auth.uid(), 'fournisseurs.modifier')
);

CREATE POLICY "fournisseurs delete via rbac or finance"
ON public.fournisseurs FOR DELETE TO authenticated
USING (
  public.has_finance_access(auth.uid())
  OR public.has_permission_v2(auth.uid(), 'fournisseurs.supprimer')
);
