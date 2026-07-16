
UPDATE public.livraisons SET livreur_id = NULL WHERE livreur_id IS NOT NULL AND livreur_id NOT IN (SELECT livreur_id FROM public.livreurs);
ALTER TABLE public.livraisons
  ADD CONSTRAINT livraisons_livreur_id_fkey
  FOREIGN KEY (livreur_id) REFERENCES public.livreurs(livreur_id) ON DELETE SET NULL;
