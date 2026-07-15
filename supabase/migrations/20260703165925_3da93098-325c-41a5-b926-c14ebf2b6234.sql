-- Durcissement des policies write sur preparateurs_colisage : has_role() au lieu de USING(true)
DROP POLICY IF EXISTS "Auth users can insert preparateurs" ON public.preparateurs_colisage;
DROP POLICY IF EXISTS "Auth users can update preparateurs" ON public.preparateurs_colisage;
DROP POLICY IF EXISTS "Auth users can delete preparateurs" ON public.preparateurs_colisage;

CREATE POLICY "Managers insert preparateurs"
  ON public.preparateurs_colisage FOR INSERT
  TO authenticated
  WITH CHECK (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_role(auth.uid(), 'directeur_general')
    OR public.has_role(auth.uid(), 'directeur_commercial')
    OR public.has_role(auth.uid(), 'gestionnaire_stock')
    OR public.has_role(auth.uid(), 'responsable_magasinier')
  );

CREATE POLICY "Managers update preparateurs"
  ON public.preparateurs_colisage FOR UPDATE
  TO authenticated
  USING (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_role(auth.uid(), 'directeur_general')
    OR public.has_role(auth.uid(), 'directeur_commercial')
    OR public.has_role(auth.uid(), 'gestionnaire_stock')
    OR public.has_role(auth.uid(), 'responsable_magasinier')
  )
  WITH CHECK (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_role(auth.uid(), 'directeur_general')
    OR public.has_role(auth.uid(), 'directeur_commercial')
    OR public.has_role(auth.uid(), 'gestionnaire_stock')
    OR public.has_role(auth.uid(), 'responsable_magasinier')
  );

CREATE POLICY "Managers delete preparateurs"
  ON public.preparateurs_colisage FOR DELETE
  TO authenticated
  USING (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_role(auth.uid(), 'directeur_general')
    OR public.has_role(auth.uid(), 'directeur_commercial')
    OR public.has_role(auth.uid(), 'gestionnaire_stock')
    OR public.has_role(auth.uid(), 'responsable_magasinier')
  );