
CREATE POLICY "authenticated read product-covers"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'product-covers');

CREATE POLICY "authenticated insert product-covers"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product-covers');

CREATE POLICY "authenticated update product-covers"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'product-covers')
WITH CHECK (bucket_id = 'product-covers');

CREATE POLICY "authenticated delete product-covers"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'product-covers');
