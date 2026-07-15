-- P1.2 — Suppression d'index strictement redondants
-- Motivation : réduire le temps de planification Postgres et le coût d'écriture
-- sans dégrader les lectures (chaque index supprimé est doublé par un autre
-- couvrant la même expression).

-- 1) clients.reference (trigramme) : deux GIN gin_trgm_ops sur la même colonne
DROP INDEX IF EXISTS public.idx_clients_ref_trgm;

-- 2) clients.type_client : deux btree identiques
DROP INDEX IF EXISTS public.idx_clients_type;

-- 3) clients.actif : idx_clients_actif_created (partial WHERE actif=true) couvre
--    déjà le filtre `actif = true` avec ORDER BY created_at DESC. L'index simple
--    idx_clients_actif est peu sélectif (booléen) et redondant.
DROP INDEX IF EXISTS public.idx_clients_actif;

-- 4) clients.nom : lower(nom) text_pattern_ops n'est pas utilisé (les ILIKE
--    passent par le GIN trigramme idx_clients_nom_trgm), et le btree simple
--    idx_clients_nom sert au tri éventuel.
DROP INDEX IF EXISTS public.idx_clients_nom_lower;

-- 5) clients.reference : lower(reference) text_pattern_ops idem — GIN trigramme
--    idx_clients_reference_trgm couvre les ILIKE.
DROP INDEX IF EXISTS public.idx_clients_reference_lower;

-- 6) notifications : deux btree identiques (date_notification DESC, created_at DESC)
DROP INDEX IF EXISTS public.idx_notifications_date_created;
