
-- Fix: gestionnaire de stock (et tout rôle RBAC habilité) ne pouvait pas voir
-- les approvisionnements créés, car les policies étaient limitées à
-- has_finance_access(). On ajoute des policies PERMISSIVE basées sur la
-- matrice RBAC v2 (has_permission) qui s'additionnent aux policies existantes.

CREATE POLICY "rbac read achats"
  ON public.achats
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (public.has_permission(auth.uid(), 'achats.voir'));

CREATE POLICY "rbac insert achats"
  ON public.achats
  AS PERMISSIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (public.has_permission(auth.uid(), 'achats.creer'));

CREATE POLICY "rbac update achats"
  ON public.achats
  AS PERMISSIVE
  FOR UPDATE
  TO authenticated
  USING (public.has_permission(auth.uid(), 'achats.modifier'))
  WITH CHECK (public.has_permission(auth.uid(), 'achats.modifier'));

CREATE POLICY "rbac delete achats"
  ON public.achats
  AS PERMISSIVE
  FOR DELETE
  TO authenticated
  USING (public.has_permission(auth.uid(), 'achats.supprimer'));
