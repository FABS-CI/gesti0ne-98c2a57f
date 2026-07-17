
-- Restreindre l'accès aux documents RH au rôle HR uniquement
DROP POLICY IF EXISTS employe_documents_auth ON public.employe_documents;

CREATE POLICY employe_documents_hr_select ON public.employe_documents
  FOR SELECT TO authenticated
  USING (public.is_hr(auth.uid()));

CREATE POLICY employe_documents_hr_insert ON public.employe_documents
  FOR INSERT TO authenticated
  WITH CHECK (public.is_hr(auth.uid()));

CREATE POLICY employe_documents_hr_update ON public.employe_documents
  FOR UPDATE TO authenticated
  USING (public.is_hr(auth.uid()))
  WITH CHECK (public.is_hr(auth.uid()));

CREATE POLICY employe_documents_hr_delete ON public.employe_documents
  FOR DELETE TO authenticated
  USING (public.is_hr(auth.uid()));

-- Restreindre les buckets storage employe-documents / employe-photos au rôle HR
DROP POLICY IF EXISTS employe_docs_auth_all ON storage.objects;

CREATE POLICY employe_docs_hr_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = ANY (ARRAY['employe-documents'::text, 'employe-photos'::text])
    AND public.is_hr(auth.uid())
  );

CREATE POLICY employe_docs_hr_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = ANY (ARRAY['employe-documents'::text, 'employe-photos'::text])
    AND public.is_hr(auth.uid())
  );

CREATE POLICY employe_docs_hr_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = ANY (ARRAY['employe-documents'::text, 'employe-photos'::text])
    AND public.is_hr(auth.uid())
  )
  WITH CHECK (
    bucket_id = ANY (ARRAY['employe-documents'::text, 'employe-photos'::text])
    AND public.is_hr(auth.uid())
  );

CREATE POLICY employe_docs_hr_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = ANY (ARRAY['employe-documents'::text, 'employe-photos'::text])
    AND public.is_hr(auth.uid())
  );
