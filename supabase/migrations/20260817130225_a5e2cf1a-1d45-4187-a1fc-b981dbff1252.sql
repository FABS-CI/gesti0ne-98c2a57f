
DO $$
BEGIN
    -- 1. Restaurer la clé étrangère entre commande_lignes et produits si elle manque
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'commande_lignes_produit_id_fkey' 
        AND table_name = 'commande_lignes'
    ) THEN
        ALTER TABLE public.commande_lignes
        ADD CONSTRAINT commande_lignes_produit_id_fkey 
        FOREIGN KEY (produit_id) REFERENCES public.produits(produit_id);
    END IF;

    -- 2. Restaurer les privilèges
    GRANT SELECT ON public.commandes TO authenticated, anon;
    GRANT SELECT ON public.commande_lignes TO authenticated, anon;
    GRANT SELECT ON public.produits TO authenticated, anon;
    GRANT SELECT ON public.bons_livraison TO authenticated, anon;
    GRANT SELECT ON public.colis TO authenticated, anon;
    GRANT SELECT ON public.colis_lignes TO authenticated, anon;
    GRANT SELECT ON public.clients TO authenticated, anon;
    GRANT SELECT ON public.preparateurs_colisage TO authenticated, anon;

END $$;
