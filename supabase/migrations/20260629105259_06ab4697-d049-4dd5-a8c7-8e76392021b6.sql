DROP POLICY IF EXISTS "auth read fne_logs" ON public.fne_logs;
CREATE POLICY "finance read fne_logs" ON public.fne_logs
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','comptable']::app_role[]));