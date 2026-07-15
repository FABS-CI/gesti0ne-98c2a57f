
-- Enums (idempotents)
DO $$ BEGIN
  CREATE TYPE public.sexe_enum AS ENUM ('M','F','autre');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.situation_matrimoniale_enum AS ENUM ('celibataire','marie','divorce','veuf','union_libre');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.type_contrat_enum AS ENUM ('CDI','CDD','stage','consultant','interim','apprentissage');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.statut_employe_enum AS ENUM ('actif','suspendu','demission','licencie','retraite','fin_contrat');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.temps_travail_enum AS ENUM ('temps_plein','temps_partiel','forfait_jour');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.mode_paiement_enum AS ENUM ('virement','cheque','especes','mobile_money');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Colonnes employes (toutes nullables / avec défauts pour rester non-destructif)
ALTER TABLE public.employes
  -- Identité
  ADD COLUMN IF NOT EXISTS prenoms text,
  ADD COLUMN IF NOT EXISTS sexe public.sexe_enum,
  ADD COLUMN IF NOT EXISTS date_naissance date,
  ADD COLUMN IF NOT EXISTS lieu_naissance text,
  ADD COLUMN IF NOT EXISTS nationalite text DEFAULT 'Ivoirienne',
  ADD COLUMN IF NOT EXISTS situation_matrimoniale public.situation_matrimoniale_enum,
  ADD COLUMN IF NOT EXISTS photo_url text,
  ADD COLUMN IF NOT EXISTS numero_cni text,
  ADD COLUMN IF NOT EXISTS numero_cnps text,
  ADD COLUMN IF NOT EXISTS numero_securite_sociale text,
  -- Contact
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS commune text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS pays text DEFAULT 'Côte d''Ivoire',
  ADD COLUMN IF NOT EXISTS telephone_secondaire text,
  -- Professionnel
  ADD COLUMN IF NOT EXISTS service text,
  ADD COLUMN IF NOT EXISTS responsable_hierarchique_id uuid REFERENCES public.employes(employe_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS type_contrat public.type_contrat_enum,
  ADD COLUMN IF NOT EXISTS date_fin_contrat date,
  ADD COLUMN IF NOT EXISTS statut_employe public.statut_employe_enum DEFAULT 'actif',
  ADD COLUMN IF NOT EXISTS temps_travail public.temps_travail_enum DEFAULT 'temps_plein',
  ADD COLUMN IF NOT EXISTS categorie text,
  ADD COLUMN IF NOT EXISTS echelon text,
  ADD COLUMN IF NOT EXISTS site_affectation text,
  -- Financier
  ADD COLUMN IF NOT EXISTS primes jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS indemnites jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS avantages jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS mode_paiement public.mode_paiement_enum DEFAULT 'virement',
  ADD COLUMN IF NOT EXISTS banque text,
  ADD COLUMN IF NOT EXISTS numero_compte text,
  ADD COLUMN IF NOT EXISTS devise text DEFAULT 'XOF',
  ADD COLUMN IF NOT EXISTS centre_cout text,
  -- Administratif
  ADD COLUMN IF NOT EXISTS niveau_etudes text,
  ADD COLUMN IF NOT EXISTS diplomes jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS competences text[] NOT NULL DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS certifications jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS contact_urgence_nom text,
  ADD COLUMN IF NOT EXISTS contact_urgence_telephone text,
  ADD COLUMN IF NOT EXISTS contact_urgence_lien text,
  ADD COLUMN IF NOT EXISTS observations text,
  -- Lien compte utilisateur
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Unicité du lien compte
CREATE UNIQUE INDEX IF NOT EXISTS employes_user_id_key
  ON public.employes(user_id) WHERE user_id IS NOT NULL;

-- Index utiles
CREATE INDEX IF NOT EXISTS idx_employes_responsable_hierarchique_id
  ON public.employes(responsable_hierarchique_id);
CREATE INDEX IF NOT EXISTS idx_employes_statut_employe
  ON public.employes(statut_employe);
CREATE INDEX IF NOT EXISTS idx_employes_type_contrat
  ON public.employes(type_contrat);

-- Validation métier : date_fin_contrat > date_embauche (via trigger, PAS CHECK time-dep)
CREATE OR REPLACE FUNCTION public.trg_employe_validate()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.date_fin_contrat IS NOT NULL
     AND NEW.date_embauche IS NOT NULL
     AND NEW.date_fin_contrat < NEW.date_embauche THEN
    RAISE EXCEPTION 'date_fin_contrat (%) doit être postérieure à date_embauche (%)',
      NEW.date_fin_contrat, NEW.date_embauche
      USING ERRCODE = 'P0001';
  END IF;
  IF NEW.date_naissance IS NOT NULL AND NEW.date_naissance > CURRENT_DATE THEN
    RAISE EXCEPTION 'date_naissance ne peut pas être dans le futur'
      USING ERRCODE = 'P0001';
  END IF;
  IF NEW.email IS NOT NULL AND NEW.email <> '' AND NEW.email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'email invalide: %', NEW.email
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_employes_validate ON public.employes;
CREATE TRIGGER trg_employes_validate
  BEFORE INSERT OR UPDATE ON public.employes
  FOR EACH ROW EXECUTE FUNCTION public.trg_employe_validate();

-- Fonction utilitaire ancienneté (mois)
CREATE OR REPLACE FUNCTION public.employe_anciennete_mois(_employe_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT GREATEST(0, (
    EXTRACT(YEAR FROM age(CURRENT_DATE, date_embauche)) * 12
    + EXTRACT(MONTH FROM age(CURRENT_DATE, date_embauche))
  )::int)
  FROM public.employes WHERE employe_id = _employe_id;
$$;
