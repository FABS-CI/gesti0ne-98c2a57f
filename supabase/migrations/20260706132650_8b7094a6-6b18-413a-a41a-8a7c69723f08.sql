
-- gares: staff-only read
DROP POLICY IF EXISTS "gares_read_all_authenticated" ON public.gares;
CREATE POLICY "gares_read_staff"
  ON public.gares FOR SELECT
  TO authenticated
  USING (is_staff(auth.uid()));

-- transporteurs: staff-only read
DROP POLICY IF EXISTS "transporteurs_read_all_authenticated" ON public.transporteurs;
CREATE POLICY "transporteurs_read_staff"
  ON public.transporteurs FOR SELECT
  TO authenticated
  USING (is_staff(auth.uid()));

-- client_fidelite_mouvements: explicit staff write policies
DROP POLICY IF EXISTS "staff insert fidelite" ON public.client_fidelite_mouvements;
CREATE POLICY "staff insert fidelite"
  ON public.client_fidelite_mouvements FOR INSERT
  TO authenticated
  WITH CHECK (is_staff(auth.uid()));

DROP POLICY IF EXISTS "staff update fidelite" ON public.client_fidelite_mouvements;
CREATE POLICY "staff update fidelite"
  ON public.client_fidelite_mouvements FOR UPDATE
  TO authenticated
  USING (is_staff(auth.uid()))
  WITH CHECK (is_staff(auth.uid()));

DROP POLICY IF EXISTS "admin delete fidelite" ON public.client_fidelite_mouvements;
CREATE POLICY "admin delete fidelite"
  ON public.client_fidelite_mouvements FOR DELETE
  TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role));
