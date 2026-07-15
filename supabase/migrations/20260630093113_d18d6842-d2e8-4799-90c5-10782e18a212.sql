
CREATE TABLE IF NOT EXISTS public.tournees (
  tournee_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE,
  date_tournee DATE NOT NULL DEFAULT CURRENT_DATE,
  responsable_nom TEXT,
  vehicule_id UUID REFERENCES public.vehicules(vehicule_id) ON DELETE SET NULL,
  chauffeur_nom TEXT,
  statut TEXT NOT NULL DEFAULT 'preparee',
  cout_carburant NUMERIC(14,2) NOT NULL DEFAULT 0,
  cout_peages NUMERIC(14,2) NOT NULL DEFAULT 0,
  cout_repas NUMERIC(14,2) NOT NULL DEFAULT 0,
  cout_expeditions NUMERIC(14,2) NOT NULL DEFAULT 0,
  cout_manutentions NUMERIC(14,2) NOT NULL DEFAULT 0,
  cout_autres NUMERIC(14,2) NOT NULL DEFAULT 0,
  cout_total NUMERIC(14,2) GENERATED ALWAYS AS (
    cout_carburant + cout_peages + cout_repas + cout_expeditions + cout_manutentions + cout_autres
  ) STORED,
  nb_colis INTEGER NOT NULL DEFAULT 0,
  nb_cartons INTEGER NOT NULL DEFAULT 0,
  nb_clients INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.tournees TO authenticated;
GRANT ALL ON public.tournees TO service_role;

ALTER TABLE public.tournees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view tournees"
  ON public.tournees FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated can insert tournees"
  ON public.tournees FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated can update tournees"
  ON public.tournees FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated can delete tournees"
  ON public.tournees FOR DELETE TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public.tournees_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS trg_tournees_updated_at ON public.tournees;
CREATE TRIGGER trg_tournees_updated_at
  BEFORE UPDATE ON public.tournees
  FOR EACH ROW EXECUTE FUNCTION public.tournees_set_updated_at();
