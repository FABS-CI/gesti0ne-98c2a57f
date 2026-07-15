CREATE POLICY "Staff can view documents-fabs"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'documents-fabs');

CREATE POLICY "Staff can upload documents-fabs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents-fabs');

CREATE POLICY "Staff can update documents-fabs"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'documents-fabs');

CREATE POLICY "Staff can delete documents-fabs"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'documents-fabs');