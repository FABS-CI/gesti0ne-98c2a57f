
CREATE TABLE public.backup_schedules (
  schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  frequence TEXT NOT NULL,
  type_sauvegarde TEXT NOT NULL DEFAULT 'complete',
  destination TEXT NOT NULL DEFAULT 'local',
  active BOOLEAN NOT NULL DEFAULT true,
  retention_count INTEGER NOT NULL DEFAULT 10,
  last_run_at TIMESTAMPTZ,
  next_run_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.backup_schedules TO authenticated;
GRANT ALL ON public.backup_schedules TO service_role;
ALTER TABLE public.backup_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated read backup_schedules"
  ON public.backup_schedules FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated manage backup_schedules"
  ON public.backup_schedules FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE TRIGGER update_backup_schedules_updated_at
  BEFORE UPDATE ON public.backup_schedules
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX idx_backup_schedules_next_run ON public.backup_schedules (next_run_at) WHERE active;
