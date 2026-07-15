-- Perf : clients — listes filtrées par "actif" et triées par date
CREATE INDEX IF NOT EXISTS idx_clients_actif_created
  ON public.clients (actif, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clients_created_at
  ON public.clients (created_at DESC);

-- Recherche par préfixe insensible à la casse (accélère les ilike 'x%')
CREATE INDEX IF NOT EXISTS idx_clients_nom_lower
  ON public.clients (lower(nom) text_pattern_ops);

CREATE INDEX IF NOT EXISTS idx_clients_reference_lower
  ON public.clients (lower(reference) text_pattern_ops);

-- Perf : notifications — tri par date pour la cloche
CREATE INDEX IF NOT EXISTS idx_notifications_date_created
  ON public.notifications (date_notification DESC, created_at DESC);

-- Perf : commande_lignes / commandes — accès frequent par commande_id
CREATE INDEX IF NOT EXISTS idx_commande_lignes_commande
  ON public.commande_lignes (commande_id);

CREATE INDEX IF NOT EXISTS idx_commandes_client_created
  ON public.commandes (client_id, created_at DESC);