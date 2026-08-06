-- Nettoyage des statuts incohérents hérités (Normalisation V2)
UPDATE public.retours SET statut = 'attente_reception' WHERE statut IN ('en_attente_magasin', 'en_cours');
UPDATE public.retours SET statut = 'attente_validation_compta' WHERE statut = 'en_attente_compta';
UPDATE public.retours SET statut = 'valide_compta' WHERE statut IN ('valide', 'accepte');
UPDATE public.retours SET statut = 'refus_magasin' WHERE statut = 'refuse_magasin';
UPDATE public.retours SET statut = 'refus_compta' WHERE statut = 'refuse_compta';
