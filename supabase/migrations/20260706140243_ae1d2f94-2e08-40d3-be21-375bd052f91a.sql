-- Historique des sauvegardes ERP
CREATE TABLE public.backups (
  backup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_email TEXT,
  type TEXT NOT NULL CHECK (type IN ('complete','base','documents','personnalisee')),
  scope JSONB,
  destination TEXT NOT NULL DEFAULT 'local' CHECK (destination IN ('local','google_drive','onedrive','dropbox','s3','b2','wasabi','r2','ftp','nas')),
  statut TEXT NOT NULL DEFAULT 'en_cours' CHECK (statut IN ('en_cours','succes','echec')),
  taille_octets BIGINT,
  duree_ms INTEGER,
  nb_tables INTEGER,
  nb_enregistrements INTEGER,
  fichier_nom TEXT,
  chiffree BOOLEAN NOT NULL DEFAULT FALSE,
  signature TEXT,
  message TEXT
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.backups TO authenticated;
GRANT ALL ON public.backups TO service_role;

ALTER TABLE public.backups ENABLE ROW LEVEL SECURITY;

-- Seuls les super_admin peuvent voir/gerer les sauvegardes
CREATE POLICY "backups_admin_select" ON public.backups FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "backups_admin_insert" ON public.backups FOR INSERT TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "backups_admin_update" ON public.backups FOR UPDATE TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'))
WITH CHECK (public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "backups_admin_delete" ON public.backups FOR DELETE TO authenticated
USING (public.has_role(auth.uid(), 'super_admin'));

CREATE INDEX idx_backups_created ON public.backups (created_at DESC);
CREATE INDEX idx_backups_statut ON public.backups (statut);