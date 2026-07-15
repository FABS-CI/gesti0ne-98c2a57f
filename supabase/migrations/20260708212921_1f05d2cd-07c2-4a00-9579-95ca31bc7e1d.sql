-- Phase 2 — Étape D2 : DROP final du code mort résiduel
DROP TRIGGER IF EXISTS trg_stocks_depots_refresh ON public.stocks_depots;
DROP FUNCTION IF EXISTS public.trg_stocks_depots_refresh() CASCADE;
DROP FUNCTION IF EXISTS public.refresh_produit_stock(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.recalculer_stock_global(text) CASCADE;
DROP FUNCTION IF EXISTS public.recalculer_stock_produit(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.audit_stock_coherence() CASCADE;