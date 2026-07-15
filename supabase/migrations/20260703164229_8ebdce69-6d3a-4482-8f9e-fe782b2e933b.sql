-- Nouvelle table libre pour les préparateurs / responsables de colisage
-- (non liée à la table employés)
CREATE TABLE public.preparateurs_colisage (
  preparateur_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  telephone TEXT,
  poste TEXT,
  depot_id UUID REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  actif BOOLEAN NOT NULL DEFAULT true,
  observations TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.preparateurs_colisage TO authenticated;
GRANT ALL ON public.preparateurs_colisage TO service_role;

ALTER TABLE public.preparateurs_colisage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Auth users can read preparateurs"
  ON public.preparateurs_colisage FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Auth users can insert preparateurs"
  ON public.preparateurs_colisage FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "Auth users can update preparateurs"
  ON public.preparateurs_colisage FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Auth users can delete preparateurs"
  ON public.preparateurs_colisage FOR DELETE
  TO authenticated USING (true);

CREATE TRIGGER trg_preparateurs_colisage_updated_at
  BEFORE UPDATE ON public.preparateurs_colisage
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX idx_preparateurs_colisage_actif ON public.preparateurs_colisage(actif);
CREATE INDEX idx_preparateurs_colisage_nom ON public.preparateurs_colisage(nom);