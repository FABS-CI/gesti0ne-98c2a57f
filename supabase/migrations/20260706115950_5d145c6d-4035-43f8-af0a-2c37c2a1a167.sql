
-- Table employe_documents
CREATE TABLE IF NOT EXISTS public.employe_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid NOT NULL REFERENCES public.employes(employe_id) ON DELETE CASCADE,
  type_document text NOT NULL DEFAULT 'autre',
  nom text NOT NULL,
  storage_path text NOT NULL UNIQUE,
  mime_type text,
  taille_octets bigint,
  uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.employe_documents TO authenticated;
GRANT ALL ON public.employe_documents TO service_role;

ALTER TABLE public.employe_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rh read employe_documents"
  ON public.employe_documents FOR SELECT
  TO authenticated
  USING (has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role, 'comptable'::app_role]));

CREATE POLICY "rh write employe_documents"
  ON public.employe_documents FOR ALL
  TO authenticated
  USING (has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role]))
  WITH CHECK (has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role]));

CREATE INDEX IF NOT EXISTS idx_employe_documents_employe_id
  ON public.employe_documents(employe_id);

CREATE TRIGGER update_employe_documents_updated_at
  BEFORE UPDATE ON public.employe_documents
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Storage policies : buckets employe-photos et employe-documents
-- Lecture (RH + comptable)
CREATE POLICY "rh read employe photos"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'employe-photos'
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role, 'comptable'::app_role])
  );

CREATE POLICY "rh write employe photos"
  ON storage.objects FOR ALL
  TO authenticated
  USING (
    bucket_id = 'employe-photos'
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role])
  )
  WITH CHECK (
    bucket_id = 'employe-photos'
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role])
  );

CREATE POLICY "rh read employe documents"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'employe-documents'
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role, 'comptable'::app_role])
  );

CREATE POLICY "rh write employe documents"
  ON storage.objects FOR ALL
  TO authenticated
  USING (
    bucket_id = 'employe-documents'
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role])
  )
  WITH CHECK (
    bucket_id = 'employe-documents'
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'secretariat'::app_role])
  );
