-- Paie CI: paramètres configurables (CNPS, CMU, ITS, IGR, etc.)
CREATE TABLE public.paie_parametres (
  parametre_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  libelle TEXT NOT NULL,
  valeur NUMERIC(18,6) NOT NULL DEFAULT 0,
  unite TEXT NOT NULL DEFAULT 'pourcentage', -- 'pourcentage' | 'montant' | 'plafond'
  categorie TEXT NOT NULL DEFAULT 'autre',   -- 'cnps' | 'cmu' | 'its' | 'igr' | 'cn' | 'autre'
  actif BOOLEAN NOT NULL DEFAULT true,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.paie_parametres TO authenticated;
GRANT ALL ON public.paie_parametres TO service_role;
ALTER TABLE public.paie_parametres ENABLE ROW LEVEL SECURITY;
CREATE POLICY "paie_parametres_auth_all" ON public.paie_parametres
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Rubriques paie personnalisables (primes, indemnités, retenues)
CREATE TABLE public.paie_rubriques (
  rubrique_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  libelle TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'gain', -- 'gain' | 'retenue' | 'patronale'
  mode_calcul TEXT NOT NULL DEFAULT 'fixe', -- 'fixe' | 'pourcentage' | 'formule'
  base TEXT NOT NULL DEFAULT 'salaire_base', -- 'salaire_base' | 'salaire_brut' | 'salaire_imposable'
  taux NUMERIC(10,4) NOT NULL DEFAULT 0,
  montant_fixe NUMERIC(18,2) NOT NULL DEFAULT 0,
  soumis_cnps BOOLEAN NOT NULL DEFAULT true,
  soumis_its BOOLEAN NOT NULL DEFAULT true,
  soumis_igr BOOLEAN NOT NULL DEFAULT true,
  ordre INTEGER NOT NULL DEFAULT 100,
  actif BOOLEAN NOT NULL DEFAULT true,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.paie_rubriques TO authenticated;
GRANT ALL ON public.paie_rubriques TO service_role;
ALTER TABLE public.paie_rubriques ENABLE ROW LEVEL SECURITY;
CREATE POLICY "paie_rubriques_auth_all" ON public.paie_rubriques
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Trigger updated_at partagé (créé s'il n'existe pas)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_paie_parametres_updated
  BEFORE UPDATE ON public.paie_parametres
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_paie_rubriques_updated
  BEFORE UPDATE ON public.paie_rubriques
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Seed paramètres CI standards (barème 2024/2025)
INSERT INTO public.paie_parametres (code, libelle, valeur, unite, categorie, description) VALUES
  ('CNPS_SALARIE_RETRAITE', 'CNPS Retraite part salariale', 6.3, 'pourcentage', 'cnps', 'Cotisation retraite salarié'),
  ('CNPS_PATRONAL_RETRAITE', 'CNPS Retraite part patronale', 7.7, 'pourcentage', 'cnps', 'Cotisation retraite employeur'),
  ('CNPS_PATRONAL_PF', 'CNPS Prestations Familiales', 5.75, 'pourcentage', 'cnps', 'Prestations familiales (patronal)'),
  ('CNPS_PATRONAL_AT', 'CNPS Accident du Travail', 2.0, 'pourcentage', 'cnps', 'AT taux moyen (2% à 5%)'),
  ('CNPS_PLAFOND_MENSUEL', 'Plafond CNPS mensuel', 2700000, 'plafond', 'cnps', 'Plafond mensuel cotisations CNPS'),
  ('CMU_SALARIE', 'CMU part salariale', 1000, 'montant', 'cmu', 'Forfait mensuel CMU salarié'),
  ('CMU_PATRONAL', 'CMU part patronale', 1000, 'montant', 'cmu', 'Forfait mensuel CMU employeur'),
  ('CN_TAUX', 'Contribution Nationale', 1.5, 'pourcentage', 'cn', 'CN sur salaire imposable'),
  ('ITS_TRANCHE1_MAX', 'ITS Tranche 1 plafond', 75000, 'plafond', 'its', 'Tranche 1 : 0 à 75 000'),
  ('ITS_TRANCHE1_TAUX', 'ITS Tranche 1 taux', 1.5, 'pourcentage', 'its', ''),
  ('ITS_TRANCHE2_MAX', 'ITS Tranche 2 plafond', 240000, 'plafond', 'its', 'Tranche 2 : 75 001 à 240 000'),
  ('ITS_TRANCHE2_TAUX', 'ITS Tranche 2 taux', 5.0, 'pourcentage', 'its', ''),
  ('ITS_TRANCHE3_MAX', 'ITS Tranche 3 plafond', 800000, 'plafond', 'its', 'Tranche 3 : 240 001 à 800 000'),
  ('ITS_TRANCHE3_TAUX', 'ITS Tranche 3 taux', 10.0, 'pourcentage', 'its', ''),
  ('ITS_TRANCHE4_MAX', 'ITS Tranche 4 plafond', 2400000, 'plafond', 'its', 'Tranche 4 : 800 001 à 2 400 000'),
  ('ITS_TRANCHE4_TAUX', 'ITS Tranche 4 taux', 15.0, 'pourcentage', 'its', ''),
  ('ITS_TRANCHE5_TAUX', 'ITS Tranche 5 taux', 20.0, 'pourcentage', 'its', 'Au-delà de 2 400 000'),
  ('ABATTEMENT_ITS', 'Abattement forfaitaire ITS', 20.0, 'pourcentage', 'its', 'Abattement 20% sur brut imposable');

-- Seed rubriques standards CI
INSERT INTO public.paie_rubriques (code, libelle, type, mode_calcul, base, taux, montant_fixe, ordre) VALUES
  ('SB', 'Salaire de base', 'gain', 'fixe', 'salaire_base', 0, 0, 10),
  ('PRIME_ANC', 'Prime d''ancienneté', 'gain', 'pourcentage', 'salaire_base', 0, 0, 20),
  ('PRIME_TRANSPORT', 'Prime de transport', 'gain', 'fixe', 'salaire_base', 0, 30000, 30),
  ('PRIME_RESPO', 'Prime de responsabilité', 'gain', 'fixe', 'salaire_base', 0, 0, 40),
  ('SURSAL', 'Sursalaire', 'gain', 'fixe', 'salaire_base', 0, 0, 50),
  ('CNPS_SAL', 'Retenue CNPS', 'retenue', 'formule', 'salaire_brut', 6.3, 0, 100),
  ('CMU_SAL', 'CMU salarié', 'retenue', 'fixe', 'salaire_brut', 0, 1000, 110),
  ('ITS', 'ITS (Impôt sur Traitements et Salaires)', 'retenue', 'formule', 'salaire_imposable', 0, 0, 120),
  ('CN', 'Contribution Nationale', 'retenue', 'formule', 'salaire_imposable', 1.5, 0, 130);