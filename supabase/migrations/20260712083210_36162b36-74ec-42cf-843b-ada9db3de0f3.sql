
DROP POLICY IF EXISTS "livraison_preuves_read" ON storage.objects;
CREATE POLICY "livraison_preuves_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'livraison-preuves'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique','directeur_commercial','comptable','secretariat']::app_role[])
  );

DROP POLICY IF EXISTS "livraison_preuves_write" ON storage.objects;
CREATE POLICY "livraison_preuves_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'livraison-preuves'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[])
  );

DROP POLICY IF EXISTS "livraison_preuves_delete" ON storage.objects;
CREATE POLICY "livraison_preuves_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'livraison-preuves'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','service_logistique']::app_role[])
  );
