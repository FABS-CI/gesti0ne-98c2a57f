
-- ==== Table backups ====
CREATE TABLE public.backups (
  backup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL DEFAULT 'complete',
  destination TEXT NOT NULL DEFAULT 'local',
  destination_ref TEXT,
  destination_url TEXT,
  statut TEXT NOT NULL DEFAULT 'en_cours',
  user_email TEXT,
  scope JSONB,
  taille_octets BIGINT,
  duree_ms INTEGER,
  nb_tables INTEGER,
  nb_enregistrements INTEGER,
  fichier_nom TEXT,
  sha256 TEXT,
  verifie BOOLEAN DEFAULT false,
  verifie_at TIMESTAMPTZ,
  verifie_methode TEXT,
  error TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.backups TO authenticated;
GRANT ALL ON public.backups TO service_role;
ALTER TABLE public.backups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "backups read authenticated" ON public.backups FOR SELECT TO authenticated USING (true);
CREATE POLICY "backups write authenticated" ON public.backups FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE TRIGGER update_backups_updated_at BEFORE UPDATE ON public.backups FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE INDEX idx_backups_created_at ON public.backups (created_at DESC);

-- ==== Table audit_logs ====
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  user_email TEXT,
  action TEXT NOT NULL,
  table_name TEXT,
  record_id TEXT,
  old_values JSONB,
  new_values JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "audit read authenticated" ON public.audit_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "audit insert authenticated" ON public.audit_logs FOR INSERT TO authenticated WITH CHECK (true);
CREATE INDEX idx_audit_logs_table_record ON public.audit_logs (table_name, record_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs (created_at DESC);

-- ==== Permissions manquantes du catalogue backup ====
INSERT INTO public.rbac_permissions (code, module, sous_module, action, libelle, description) VALUES
  ('backup.planifier',     'administration', 'backup', 'planifier',     'Planifier une sauvegarde',      'Créer/planifier des sauvegardes'),
  ('backup.restaurer',     'administration', 'backup', 'restaurer',     'Restaurer une sauvegarde',      'Restaurer les données depuis une sauvegarde'),
  ('backup.exporter_csv',  'administration', 'backup', 'exporter_csv',  'Exporter une sauvegarde en CSV','Exporter une sauvegarde au format CSV')
ON CONFLICT (code) DO NOTHING;
