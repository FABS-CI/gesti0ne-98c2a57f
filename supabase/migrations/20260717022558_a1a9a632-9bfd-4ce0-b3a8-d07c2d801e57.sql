
-- Generic trigger to auto-fill exercice_id on tables that have it
CREATE OR REPLACE FUNCTION public._set_exercice_id_before_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='public' AS $$
DECLARE v_date date; v_col text;
BEGIN
  IF to_jsonb(NEW) ? 'exercice_id' AND (to_jsonb(NEW)->>'exercice_id') IS NULL THEN
    -- pick a date column if present
    v_date := COALESCE(
      (to_jsonb(NEW)->>'date_achat')::date,
      (to_jsonb(NEW)->>'date_bl')::date,
      (to_jsonb(NEW)->>'date_ecriture')::date,
      (to_jsonb(NEW)->>'date_facture')::date,
      (to_jsonb(NEW)->>'date_paiement')::date,
      (to_jsonb(NEW)->>'date_transaction')::date,
      (to_jsonb(NEW)->>'date_commande')::date,
      CURRENT_DATE
    );
    NEW.exercice_id := COALESCE(
      public._resolve_exercice_id(v_date),
      (SELECT exercice_id FROM public.exercices_comptables WHERE is_actif=true ORDER BY date_debut DESC LIMIT 1),
      (SELECT exercice_id FROM public.exercices_comptables ORDER BY date_debut DESC LIMIT 1)
    );
  END IF;
  RETURN NEW;
END; $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['achats','bons_livraison','ecritures_comptables','factures','paiements','transactions']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_set_exercice_id ON public.%I', t);
    EXECUTE format('CREATE TRIGGER trg_set_exercice_id BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public._set_exercice_id_before_insert()', t);
  END LOOP;
END $$;

-- Backfill existing rows
UPDATE public.achats SET exercice_id = COALESCE(public._resolve_exercice_id(date_achat), public._resolve_exercice_id(CURRENT_DATE)) WHERE exercice_id IS NULL;
UPDATE public.bons_livraison SET exercice_id = public._resolve_exercice_id(COALESCE(created_at::date, CURRENT_DATE)) WHERE exercice_id IS NULL;
UPDATE public.ecritures_comptables SET exercice_id = COALESCE(public._resolve_exercice_id(date_ecriture), public._resolve_exercice_id(CURRENT_DATE)) WHERE exercice_id IS NULL;
UPDATE public.factures SET exercice_id = COALESCE(public._resolve_exercice_id(date_facture), public._resolve_exercice_id(CURRENT_DATE)) WHERE exercice_id IS NULL;
UPDATE public.paiements SET exercice_id = COALESCE(public._resolve_exercice_id(date_paiement), public._resolve_exercice_id(CURRENT_DATE)) WHERE exercice_id IS NULL;
UPDATE public.transactions SET exercice_id = COALESCE(public._resolve_exercice_id(date_transaction), public._resolve_exercice_id(CURRENT_DATE)) WHERE exercice_id IS NULL;
