-- Normalize type_client values so the front-end filter (singular values) matches DB rows.
UPDATE public.clients SET type_client = 'librairie'       WHERE type_client = 'librairies';
UPDATE public.clients SET type_client = 'lycee'           WHERE type_client = 'lycees';
UPDATE public.clients SET type_client = 'college'         WHERE type_client IN ('colleges','collège','collèges');
UPDATE public.clients SET type_client = 'particulier'     WHERE type_client = 'particuliers';
UPDATE public.clients SET type_client = 'groupe_scolaire' WHERE type_client IN ('groupe scolaire','groupe-scolaire','groupes scolaires');

-- Performance indexes for the clients list (type filter + text search + ordering).
CREATE INDEX IF NOT EXISTS idx_clients_type_client ON public.clients (type_client);
CREATE INDEX IF NOT EXISTS idx_clients_actif       ON public.clients (actif);
CREATE INDEX IF NOT EXISTS idx_clients_created_at  ON public.clients (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clients_nom_trgm    ON public.clients USING gin (nom gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_ref_trgm    ON public.clients USING gin (reference gin_trgm_ops);
