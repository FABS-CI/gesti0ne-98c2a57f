-- Allow editing/deleting a delivery-tracking step
CREATE POLICY livsuivi_historique_update ON public.livsuivi_historique
  FOR UPDATE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'service_logistique'::app_role]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'service_logistique'::app_role]));

CREATE POLICY livsuivi_historique_delete ON public.livsuivi_historique
  FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));