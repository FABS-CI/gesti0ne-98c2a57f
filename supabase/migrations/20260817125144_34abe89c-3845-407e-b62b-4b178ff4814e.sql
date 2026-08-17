GRANT SELECT ON public.commandes TO authenticated, anon;
GRANT SELECT ON public.commande_lignes TO authenticated, anon;
GRANT SELECT ON public.produits TO authenticated, anon;
GRANT SELECT ON public.bons_livraison TO authenticated, anon;
GRANT SELECT ON public.colis TO authenticated, anon;
GRANT SELECT ON public.colis_lignes TO authenticated, anon;
GRANT SELECT ON public.clients TO authenticated, anon;
GRANT SELECT ON public.preparateurs_colisage TO authenticated, anon;
GRANT SELECT ON public.stocks_depots TO authenticated, anon;
GRANT SELECT ON public.depots TO authenticated, anon;

-- Verification query
SELECT grantee, table_name, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name IN ('commandes', 'commande_lignes', 'produits') 
AND grantee = 'authenticated';