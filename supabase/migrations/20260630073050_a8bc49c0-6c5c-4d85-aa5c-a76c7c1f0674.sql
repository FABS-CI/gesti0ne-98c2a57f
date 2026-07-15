
-- fne_factures : extension
ALTER TABLE public.fne_factures
  ADD COLUMN IF NOT EXISTS template text DEFAULT 'B2B',
  ADD COLUMN IF NOT EXISTS payment_method text DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS invoice_type text DEFAULT 'sale',
  ADD COLUMN IF NOT EXISTS client_ncc text,
  ADD COLUMN IF NOT EXISTS client_telephone text,
  ADD COLUMN IF NOT EXISTS client_email text,
  ADD COLUMN IF NOT EXISTS client_seller_name text,
  ADD COLUMN IF NOT EXISTS point_of_sale text DEFAULT '01',
  ADD COLUMN IF NOT EXISTS establishment text DEFAULT 'Siège Social',
  ADD COLUMN IF NOT EXISTS commercial_message text,
  ADD COLUMN IF NOT EXISTS footer text,
  ADD COLUMN IF NOT EXISTS items jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS discount numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS qr_code text,
  ADD COLUMN IF NOT EXISTS token text,
  ADD COLUMN IF NOT EXISTS verification_url text,
  ADD COLUMN IF NOT EXISTS response_payload jsonb,
  ADD COLUMN IF NOT EXISTS error_message text,
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz,
  ADD COLUMN IF NOT EXISTS validated_at timestamptz,
  ADD COLUMN IF NOT EXISTS retry_count int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS balance_sticker int,
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'sandbox',
  ADD COLUMN IF NOT EXISTS parent_fne_id uuid REFERENCES public.fne_factures(fne_id),
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- fne_logs : extension
ALTER TABLE public.fne_logs
  ADD COLUMN IF NOT EXISTS http_status int,
  ADD COLUMN IF NOT EXISTS attempt_number int DEFAULT 1,
  ADD COLUMN IF NOT EXISTS duration_ms int,
  ADD COLUMN IF NOT EXISTS user_nom text;

-- Index utiles
CREATE INDEX IF NOT EXISTS idx_fne_factures_statut ON public.fne_factures(statut);
CREATE INDEX IF NOT EXISTS idx_fne_factures_created_at ON public.fne_factures(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fne_logs_facture ON public.fne_logs(fne_facture_id);
CREATE INDEX IF NOT EXISTS idx_fne_logs_created ON public.fne_logs(created_at DESC);

-- Trigger updated_at sur fne_factures
DROP TRIGGER IF EXISTS trg_fne_factures_updated ON public.fne_factures;
CREATE TRIGGER trg_fne_factures_updated BEFORE UPDATE ON public.fne_factures
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Paramètres FNE par défaut (idempotent)
INSERT INTO public.fne_settings(cle, valeur, description) VALUES
  ('company_ncc', '2302562N', 'Numéro de Compte Contribuable'),
  ('company_idu', 'CI-2023-0052129 E', 'Identifiant Unique'),
  ('company_name', 'EDITIONS FABS-CI', 'Raison sociale'),
  ('company_regime', 'TEE', 'Régime fiscal'),
  ('company_secteur', 'EDITION', 'Secteur d''activité'),
  ('company_dran', 'DRAN VI', 'Direction régionale'),
  ('company_centre_impots', '962 Impôts de Bingerville', 'Centre des impôts'),
  ('point_of_sale', '01', 'Point de vente'),
  ('establishment', 'Siège Social', 'Établissement'),
  ('dgi_api_url_test', 'http://54.247.95.108/ws', 'URL API DGI (test)'),
  ('dgi_api_url_prod', '', 'URL API DGI (production)'),
  ('use_production', 'false', 'Mode production activé'),
  ('retry_max_attempts', '5', 'Nombre max de tentatives')
ON CONFLICT (cle) DO NOTHING;
