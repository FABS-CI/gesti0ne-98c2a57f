-- P1.2b — Suite du nettoyage d'index redondants
DROP INDEX IF EXISTS public.idx_commandes_client;      -- = idx_commandes_client_id
DROP INDEX IF EXISTS public.idx_commandes_date;        -- = idx_commandes_date_commande

DROP INDEX IF EXISTS public.idx_factures_client;       -- = idx_factures_client_id
DROP INDEX IF EXISTS public.idx_factures_commande;     -- = idx_factures_commande_id

DROP INDEX IF EXISTS public.idx_produits_reference;    -- couvert par la contrainte UNIQUE produits_reference_key
DROP INDEX IF EXISTS public.idx_produits_actif;        -- couvert par idx_produits_actif_created
