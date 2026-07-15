-- Corrige la fuite : les clés `dgi_api_key_test` / `dgi_api_key_prod` étaient
-- lisibles côté client (la policy précédente ne bloquait que le nom exact
-- `dgi_api_key`). On bloque désormais tout `cle` commençant par `dgi_api_key`.

DROP POLICY IF EXISTS "fne_settings read (no secret)" ON public.fne_settings;
DROP POLICY IF EXISTS "fne_settings write (no secret)" ON public.fne_settings;

CREATE POLICY "fne_settings read (no dgi keys)" ON public.fne_settings
  FOR SELECT TO authenticated
  USING (
    cle NOT LIKE 'dgi_api_key%'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[])
  );

CREATE POLICY "fne_settings write (no dgi keys)" ON public.fne_settings
  FOR ALL TO authenticated
  USING (
    cle NOT LIKE 'dgi_api_key%'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[])
  )
  WITH CHECK (
    cle NOT LIKE 'dgi_api_key%'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[])
  );