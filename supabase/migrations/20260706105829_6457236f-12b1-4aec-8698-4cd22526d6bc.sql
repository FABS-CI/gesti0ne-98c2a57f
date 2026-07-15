
-- 1. TRANSPORTEURS ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transporteurs (
  transporteur_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom             TEXT NOT NULL,
  contact         TEXT,
  telephone       TEXT,
  email           TEXT,
  type            TEXT,
  actif           BOOLEAN NOT NULL DEFAULT true,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.transporteurs TO authenticated;
GRANT ALL ON public.transporteurs TO service_role;

ALTER TABLE public.transporteurs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "transporteurs_read_all_authenticated"
  ON public.transporteurs FOR SELECT TO authenticated USING (true);

CREATE POLICY "transporteurs_write_admin"
  ON public.transporteurs FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin')
      OR public.has_role(auth.uid(), 'directeur_general'))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin')
      OR public.has_role(auth.uid(), 'directeur_general'));

CREATE TRIGGER trg_transporteurs_updated
  BEFORE UPDATE ON public.transporteurs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2. GARES ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gares (
  gare_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom         TEXT NOT NULL,
  ville       TEXT,
  code        TEXT UNIQUE,
  actif       BOOLEAN NOT NULL DEFAULT true,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.gares TO authenticated;
GRANT ALL ON public.gares TO service_role;

ALTER TABLE public.gares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gares_read_all_authenticated"
  ON public.gares FOR SELECT TO authenticated USING (true);

CREATE POLICY "gares_write_admin"
  ON public.gares FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin')
      OR public.has_role(auth.uid(), 'directeur_general'))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin')
      OR public.has_role(auth.uid(), 'directeur_general'));

CREATE TRIGGER trg_gares_updated
  BEFORE UPDATE ON public.gares
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 3. LIVRAISONS — colonnes de liaison -------------------------------------
ALTER TABLE public.livraisons
  ADD COLUMN IF NOT EXISTS client_id         UUID REFERENCES public.clients(client_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS expedition_id     UUID REFERENCES public.expeditions(expedition_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS bl_id             UUID REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS livreur_id        UUID REFERENCES public.livreurs(livreur_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS transporteur_id   UUID REFERENCES public.transporteurs(transporteur_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS gare_depart_id    UUID REFERENCES public.gares(gare_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS gare_arrivee_id   UUID REFERENCES public.gares(gare_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ville             TEXT,
  ADD COLUMN IF NOT EXISTS commune           TEXT,
  ADD COLUMN IF NOT EXISTS telephone_dest    TEXT,
  ADD COLUMN IF NOT EXISTS contact_dest      TEXT,
  ADD COLUMN IF NOT EXISTS figee             BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_livraisons_client_id       ON public.livraisons(client_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_expedition_id   ON public.livraisons(expedition_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_bl_id           ON public.livraisons(bl_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_livreur_id      ON public.livraisons(livreur_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_transporteur_id ON public.livraisons(transporteur_id);
