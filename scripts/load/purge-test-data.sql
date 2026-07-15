-- Purge all TEST_ prefixed load-test data. Safe: does not touch real rows.
-- Run: psql -f scripts/load/purge-test-data.sql

BEGIN;

-- Order matters: children first (FKs cascade will also handle it, but explicit is safer).
DELETE FROM public.colis         WHERE reference LIKE 'TEST\_%' ESCAPE '\';
DELETE FROM public.commandes     WHERE reference LIKE 'TEST\_%' ESCAPE '\';
DELETE FROM public.clients       WHERE reference LIKE 'TEST\_%' ESCAPE '\';

SELECT 'clients_restants_TEST' AS label, count(*) FROM public.clients WHERE reference LIKE 'TEST\_%' ESCAPE '\'
UNION ALL SELECT 'commandes_restantes_TEST', count(*) FROM public.commandes WHERE reference LIKE 'TEST\_%' ESCAPE '\'
UNION ALL SELECT 'colis_restants_TEST', count(*) FROM public.colis WHERE reference LIKE 'TEST\_%' ESCAPE '\';

COMMIT;