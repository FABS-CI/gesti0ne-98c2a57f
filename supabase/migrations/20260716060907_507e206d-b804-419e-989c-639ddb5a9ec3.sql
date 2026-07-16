
CREATE TABLE IF NOT EXISTS public.preparateurs_colisage (
  preparateur_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  telephone text,
  poste text,
  depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  actif boolean NOT NULL DEFAULT true,
  observations text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.preparateurs_colisage TO authenticated;
GRANT ALL ON public.preparateurs_colisage TO service_role;

ALTER TABLE public.preparateurs_colisage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_read_preparateurs_colisage" ON public.preparateurs_colisage
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_write_preparateurs_colisage" ON public.preparateurs_colisage
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE TRIGGER update_preparateurs_colisage_updated_at
  BEFORE UPDATE ON public.preparateurs_colisage
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
