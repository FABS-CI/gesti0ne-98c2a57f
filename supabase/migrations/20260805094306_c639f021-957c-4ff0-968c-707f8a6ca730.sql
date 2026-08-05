-- Supprimer la colonne contact qui est remplacée par representant
ALTER TABLE public.fournisseurs DROP COLUMN IF EXISTS contact;
