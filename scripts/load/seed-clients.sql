-- Seed 50k+ clients with TEST_ prefix for load testing.
-- Safe purge via: DELETE FROM public.clients WHERE reference LIKE 'TEST\_%' ESCAPE '\';
-- Run:  psql -f scripts/load/seed-clients.sql -v n=50000

\set n 50000

INSERT INTO public.clients (reference, nom, type_client, telephone, email, ville, commune, actif)
SELECT
  'TEST_CLI_' || lpad(g::text, 7, '0'),
  'TEST_Client_' || g,
  (ARRAY['particulier','entreprise','ecole','autre'])[1 + (g % 4)],
  '07' || lpad((10000000 + (g % 89999999))::text, 8, '0'),
  'test' || g || '@load.example',
  (ARRAY['Abidjan','Bouake','Yamoussoukro','San-Pedro','Korhogo','Daloa','Man'])[1 + (g % 7)],
  (ARRAY['Cocody','Yopougon','Plateau','Marcory','Adjame','Treichville','Abobo','Koumassi'])[1 + (g % 8)],
  true
FROM generate_series(1, :n) AS g
ON CONFLICT DO NOTHING;

SELECT count(*) AS test_clients FROM public.clients WHERE reference LIKE 'TEST\_%' ESCAPE '\';