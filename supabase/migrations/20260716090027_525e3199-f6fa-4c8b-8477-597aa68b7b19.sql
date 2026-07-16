
DROP POLICY IF EXISTS factures_read ON public.factures;
DROP POLICY IF EXISTS paiements_read ON public.paiements;
CREATE POLICY factures_read ON public.factures FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
CREATE POLICY paiements_read ON public.paiements FOR SELECT TO authenticated USING (public.is_finance(auth.uid()));
