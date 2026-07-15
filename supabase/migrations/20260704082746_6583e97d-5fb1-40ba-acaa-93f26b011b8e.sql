
-- =========================================================================
-- Lot 2 — Gestion des exercices scolaires
-- =========================================================================

-- 1) Enum statut exercice
DO $$ BEGIN
  CREATE TYPE public.exercice_statut AS ENUM ('preparation','actif','cloture_en_cours','cloture','archive');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Helper : rôle "admin" (super_admin ou directeur_general)
CREATE OR REPLACE FUNCTION public.is_exercice_admin(_uid uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.has_role(_uid, 'super_admin'::app_role)
      OR public.has_role(_uid, 'directeur_general'::app_role);
$$;

-- 2) Table exercices
CREATE TABLE IF NOT EXISTS public.exercices (
  exercice_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text NOT NULL UNIQUE,
  date_debut    date NOT NULL,
  date_fin      date NOT NULL,
  statut        public.exercice_statut NOT NULL DEFAULT 'preparation',
  is_actif      boolean NOT NULL DEFAULT false,
  date_cloture  timestamptz,
  cloture_par   uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exercice_dates_ordre CHECK (date_fin > date_debut)
);
CREATE UNIQUE INDEX IF NOT EXISTS exercices_unique_actif ON public.exercices (is_actif) WHERE is_actif = true;
CREATE INDEX IF NOT EXISTS exercices_dates_idx ON public.exercices (date_debut, date_fin);

GRANT SELECT ON public.exercices TO authenticated;
GRANT ALL ON public.exercices TO service_role;
ALTER TABLE public.exercices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exercices_select" ON public.exercices
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "exercices_admin_all" ON public.exercices
  FOR ALL TO authenticated
  USING (public.is_exercice_admin(auth.uid()))
  WITH CHECK (public.is_exercice_admin(auth.uid()));

-- 3) Seed
INSERT INTO public.exercices (code, date_debut, date_fin, statut, is_actif) VALUES
  ('2024-2025','2024-08-01','2025-07-31','archive',    false),
  ('2025-2026','2025-08-01','2026-07-31','archive',    false),
  ('2026-2027','2026-08-01','2027-07-31','actif',      true),
  ('2027-2028','2027-08-01','2028-07-31','preparation',false)
ON CONFLICT (code) DO NOTHING;

-- 4) Helper de résolution date -> exercice
CREATE OR REPLACE FUNCTION public.exercice_pour_date(_d timestamptz)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT exercice_id FROM public.exercices
      WHERE _d::date BETWEEN date_debut AND date_fin LIMIT 1),
    (SELECT exercice_id FROM public.exercices WHERE is_actif LIMIT 1)
  );
$$;

-- 5) Tables de reports
CREATE TABLE IF NOT EXISTS public.soldes_ouverture_clients (
  solde_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercice_id         uuid NOT NULL REFERENCES public.exercices(exercice_id) ON DELETE RESTRICT,
  client_id           uuid NOT NULL,
  montant             numeric(18,2) NOT NULL,
  exercice_origine_id uuid REFERENCES public.exercices(exercice_id) ON DELETE SET NULL,
  commentaire         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid,
  UNIQUE (exercice_id, client_id)
);
CREATE INDEX IF NOT EXISTS soc_client_idx   ON public.soldes_ouverture_clients (client_id);
CREATE INDEX IF NOT EXISTS soc_exercice_idx ON public.soldes_ouverture_clients (exercice_id);
GRANT SELECT ON public.soldes_ouverture_clients TO authenticated;
GRANT ALL ON public.soldes_ouverture_clients TO service_role;
ALTER TABLE public.soldes_ouverture_clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "soc_select" ON public.soldes_ouverture_clients FOR SELECT TO authenticated USING (true);
CREATE POLICY "soc_admin_all" ON public.soldes_ouverture_clients FOR ALL TO authenticated
  USING (public.is_exercice_admin(auth.uid()))
  WITH CHECK (public.is_exercice_admin(auth.uid()));

CREATE TABLE IF NOT EXISTS public.soldes_ouverture_fournisseurs (
  solde_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercice_id         uuid NOT NULL REFERENCES public.exercices(exercice_id) ON DELETE RESTRICT,
  fournisseur_id      uuid NOT NULL,
  montant             numeric(18,2) NOT NULL,
  exercice_origine_id uuid REFERENCES public.exercices(exercice_id) ON DELETE SET NULL,
  commentaire         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid,
  UNIQUE (exercice_id, fournisseur_id)
);
CREATE INDEX IF NOT EXISTS sof_four_idx     ON public.soldes_ouverture_fournisseurs (fournisseur_id);
CREATE INDEX IF NOT EXISTS sof_exercice_idx ON public.soldes_ouverture_fournisseurs (exercice_id);
GRANT SELECT ON public.soldes_ouverture_fournisseurs TO authenticated;
GRANT ALL ON public.soldes_ouverture_fournisseurs TO service_role;
ALTER TABLE public.soldes_ouverture_fournisseurs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sof_select" ON public.soldes_ouverture_fournisseurs FOR SELECT TO authenticated USING (true);
CREATE POLICY "sof_admin_all" ON public.soldes_ouverture_fournisseurs FOR ALL TO authenticated
  USING (public.is_exercice_admin(auth.uid()))
  WITH CHECK (public.is_exercice_admin(auth.uid()));

-- 6) Journal de clôture
CREATE TABLE IF NOT EXISTS public.exercice_cloture_journal (
  journal_id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercice_source_id         uuid NOT NULL REFERENCES public.exercices(exercice_id),
  exercice_cible_id          uuid NOT NULL REFERENCES public.exercices(exercice_id),
  cloture_par                uuid,
  date_cloture               timestamptz NOT NULL DEFAULT now(),
  nb_clients_reportes        integer NOT NULL DEFAULT 0,
  montant_total_clients      numeric(18,2) NOT NULL DEFAULT 0,
  nb_fournisseurs_reportes   integer NOT NULL DEFAULT 0,
  montant_total_fournisseurs numeric(18,2) NOT NULL DEFAULT 0,
  details                    jsonb,
  UNIQUE (exercice_source_id, exercice_cible_id)
);
GRANT SELECT ON public.exercice_cloture_journal TO authenticated;
GRANT ALL ON public.exercice_cloture_journal TO service_role;
ALTER TABLE public.exercice_cloture_journal ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ecj_select" ON public.exercice_cloture_journal FOR SELECT TO authenticated USING (true);
CREATE POLICY "ecj_admin_all" ON public.exercice_cloture_journal FOR ALL TO authenticated
  USING (public.is_exercice_admin(auth.uid()))
  WITH CHECK (public.is_exercice_admin(auth.uid()));

-- 7) Ajout exercice_id + backfill + NOT NULL
DO $$
DECLARE
  r record;
  actif_id uuid;
BEGIN
  SELECT exercice_id INTO actif_id FROM public.exercices WHERE is_actif;
  FOR r IN
    SELECT * FROM (VALUES
      ('commandes','date_commande'),
      ('proformas','date_proforma'),
      ('factures','date_facture'),
      ('bons_livraison','date_emission'),
      ('bons_retour','date_retour'),
      ('retours','date_retour'),
      ('achats','date_achat'),
      ('paiements','date_paiement'),
      ('transactions','date_transaction'),
      ('stock_mouvements','created_at'),
      ('inventaires','date_inventaire'),
      ('bulletins_paie','created_at'),
      ('ecritures_comptables','date_ecriture')
    ) AS t(tbl,dcol)
  LOOP
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS exercice_id uuid REFERENCES public.exercices(exercice_id) ON DELETE RESTRICT', r.tbl);
    EXECUTE format('UPDATE public.%I SET exercice_id = public.exercice_pour_date(%I::timestamptz) WHERE exercice_id IS NULL', r.tbl, r.dcol);
    EXECUTE format('UPDATE public.%I SET exercice_id = $1 WHERE exercice_id IS NULL', r.tbl) USING actif_id;
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN exercice_id SET NOT NULL', r.tbl);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I (exercice_id)', r.tbl || '_exercice_idx', r.tbl);
  END LOOP;
END $$;

-- 8) Trigger updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS trg_exercices_updated_at ON public.exercices;
CREATE TRIGGER trg_exercices_updated_at
  BEFORE UPDATE ON public.exercices
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
