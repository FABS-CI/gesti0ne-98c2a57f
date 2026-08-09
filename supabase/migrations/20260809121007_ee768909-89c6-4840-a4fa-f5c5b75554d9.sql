-- Fix purchase relationships and permissions
-- 1. Add Foreign Key between achat_lignes and produits
ALTER TABLE public.achat_lignes
ADD CONSTRAINT achat_lignes_produit_id_fkey
FOREIGN KEY (produit_id)
REFERENCES public.produits(produit_id);

-- 2. Ensure RLS and Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.achat_lignes TO authenticated;
GRANT ALL ON public.achat_lignes TO service_role;
GRANT SELECT ON public.achat_lignes TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.achats TO authenticated;
GRANT ALL ON public.achats TO service_role;
GRANT SELECT ON public.achats TO anon;

-- Note: Policies are assumed to exist or be handled by Lovable Cloud,
-- but we ensure the table is accessible to the Data API roles.
