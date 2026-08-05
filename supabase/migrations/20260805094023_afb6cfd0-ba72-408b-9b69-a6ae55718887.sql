-- Étape 1 : Ajouter la colonne representant à la table fournisseurs
ALTER TABLE public.fournisseurs ADD COLUMN IF NOT EXISTS representant text;

-- Étape 2 : Mettre à jour les privilèges
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fournisseurs TO authenticated;
GRANT ALL ON public.fournisseurs TO service_role;
