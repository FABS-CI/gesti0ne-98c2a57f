
-- 1. Extension enum livsuivi_statut : nouveaux statuts pour suivi multi-clients
ALTER TYPE public.livsuivi_statut ADD VALUE IF NOT EXISTS 'chargee';
ALTER TYPE public.livsuivi_statut ADD VALUE IF NOT EXISTS 'en_route';
ALTER TYPE public.livsuivi_statut ADD VALUE IF NOT EXISTS 'reception_confirmee';
ALTER TYPE public.livsuivi_statut ADD VALUE IF NOT EXISTS 'non_livre';
