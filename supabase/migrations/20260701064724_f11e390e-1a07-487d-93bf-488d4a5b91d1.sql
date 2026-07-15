-- Type de livraison
DO $$ BEGIN
  CREATE TYPE public.type_livraison AS ENUM ('directe', 'expedition');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Nouveaux statuts de livraison de commande
ALTER TYPE public.statut_livraison_cmd ADD VALUE IF NOT EXISTS 'assignee';
ALTER TYPE public.statut_livraison_cmd ADD VALUE IF NOT EXISTS 'chargee';
ALTER TYPE public.statut_livraison_cmd ADD VALUE IF NOT EXISTS 'en_route';
ALTER TYPE public.statut_livraison_cmd ADD VALUE IF NOT EXISTS 'deposee_gare';
ALTER TYPE public.statut_livraison_cmd ADD VALUE IF NOT EXISTS 'arrivee_destination';
ALTER TYPE public.statut_livraison_cmd ADD VALUE IF NOT EXISTS 'retiree_client';
ALTER TYPE public.statut_livraison_cmd ADD VALUE IF NOT EXISTS 'retour';

-- Table livreurs
CREATE TABLE IF NOT EXISTS public.livreurs (
  livreur_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  telephone text,
  societe text,
  vehicule_defaut text,
  immatriculation text,
  observations text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.livreurs TO authenticated;
GRANT ALL ON public.livreurs TO service_role;

ALTER TABLE public.livreurs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "livreurs_read" ON public.livreurs
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY[
    'super_admin'::app_role,
    'directeur_general'::app_role,
    'service_logistique'::app_role,
    'directeur_commercial'::app_role,
    'comptable'::app_role,
    'responsable_magasinier'::app_role,
    'gestionnaire_stock'::app_role
  ]));

CREATE POLICY "livreurs_insert" ON public.livreurs
  FOR INSERT TO authenticated
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY[
    'super_admin'::app_role,
    'directeur_general'::app_role,
    'service_logistique'::app_role
  ]));

CREATE POLICY "livreurs_update" ON public.livreurs
  FOR UPDATE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY[
    'super_admin'::app_role,
    'directeur_general'::app_role,
    'service_logistique'::app_role
  ]));

CREATE POLICY "livreurs_delete" ON public.livreurs
  FOR DELETE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role]));

CREATE TRIGGER trg_livreurs_updated_at
  BEFORE UPDATE ON public.livreurs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Enrichissement tournees
ALTER TABLE public.tournees
  ADD COLUMN IF NOT EXISTS livreur_id uuid REFERENCES public.livreurs(livreur_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tournees_livreur ON public.tournees(livreur_id);

-- Enrichissement livraisons_commande
ALTER TABLE public.livraisons_commande
  ADD COLUMN IF NOT EXISTS tournee_id uuid REFERENCES public.tournees(tournee_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS type_livraison public.type_livraison,
  ADD COLUMN IF NOT EXISTS gare_nom text,
  ADD COLUMN IF NOT EXISTS livreur_id uuid REFERENCES public.livreurs(livreur_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS heure_depart timestamptz;

CREATE INDEX IF NOT EXISTS idx_livraisons_commande_tournee ON public.livraisons_commande(tournee_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_commande_livreur ON public.livraisons_commande(livreur_id);