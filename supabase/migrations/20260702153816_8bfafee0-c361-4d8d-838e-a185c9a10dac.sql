
-- Enable trigram extension for fast ILIKE '%text%' searches
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- CLIENTS : top offender (72s CPU cumulé sur 4 requêtes)
-- ============================================================

-- Filtre actif=true + ORDER BY created_at DESC → index composite partiel
CREATE INDEX IF NOT EXISTS idx_clients_actif_created
  ON public.clients (created_at DESC)
  WHERE actif = true;

-- Filtre actif seul (COUNT, listes simples)
CREATE INDEX IF NOT EXISTS idx_clients_actif
  ON public.clients (actif);

-- Recherche ILIKE '%text%' sur 3 colonnes → GIN trigram
CREATE INDEX IF NOT EXISTS idx_clients_nom_trgm
  ON public.clients USING gin (nom gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_reference_trgm
  ON public.clients USING gin (reference gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_representant_trgm
  ON public.clients USING gin (representant gin_trgm_ops);

-- L'ancien idx_clients_nom (btree) est inutile pour ILIKE — on le garde
-- au cas où il sert à un ORDER BY nom, mais on ne le supprime pas ici.

-- ============================================================
-- PRODUITS : filtre actif=true systématique
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_produits_actif
  ON public.produits (actif);
CREATE INDEX IF NOT EXISTS idx_produits_actif_ordre
  ON public.produits (niveau_ordre, titre)
  WHERE actif = true;
CREATE INDEX IF NOT EXISTS idx_produits_titre_trgm
  ON public.produits USING gin (titre gin_trgm_ops);

-- ============================================================
-- COMMANDES : listes filtrées par statut + date
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_commandes_statut
  ON public.commandes (statut);
CREATE INDEX IF NOT EXISTS idx_commandes_date
  ON public.commandes (date_commande DESC);
CREATE INDEX IF NOT EXISTS idx_commandes_reference_trgm
  ON public.commandes USING gin (reference gin_trgm_ops);

-- ============================================================
-- FACTURES : dashboard CA + listes filtrées
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_factures_client
  ON public.factures (client_id);
CREATE INDEX IF NOT EXISTS idx_factures_statut
  ON public.factures (statut);
CREATE INDEX IF NOT EXISTS idx_factures_date
  ON public.factures (date_facture DESC);
CREATE INDEX IF NOT EXISTS idx_factures_commande
  ON public.factures (commande_id);

-- ============================================================
-- BONS DE LIVRAISON : recherches par commande/client
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_bl_commande
  ON public.bons_livraison (commande_id);
CREATE INDEX IF NOT EXISTS idx_bl_statut
  ON public.bons_livraison (statut);
CREATE INDEX IF NOT EXISTS idx_bl_date
  ON public.bons_livraison (date_livraison DESC);

-- ============================================================
-- COLIS : lookup par référence QR + statut
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_colis_statut
  ON public.colis (statut);

-- Rafraîchir les statistiques pour que le planner utilise les nouveaux index immédiatement
ANALYZE public.clients;
ANALYZE public.produits;
ANALYZE public.commandes;
ANALYZE public.factures;
ANALYZE public.bons_livraison;
ANALYZE public.colis;
