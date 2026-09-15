ALTER TABLE public.document_certifications
  ADD COLUMN IF NOT EXISTS verification_token TEXT,
  ADD COLUMN IF NOT EXISTS verification_url TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS document_certifications_verification_token_key
  ON public.document_certifications (verification_token)
  WHERE verification_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS document_certifications_token_hash_idx
  ON public.document_certifications (token_hash);

CREATE INDEX IF NOT EXISTS document_certifications_doc_idx
  ON public.document_certifications (document_type, document_id, version DESC);