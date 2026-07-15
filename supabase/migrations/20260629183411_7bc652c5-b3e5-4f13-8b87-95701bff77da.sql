
-- 1. Guard suppression client
CREATE OR REPLACE FUNCTION public.guard_client_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.factures WHERE client_id = OLD.client_id) THEN
    RAISE EXCEPTION 'Suppression interdite: client lié à une ou plusieurs factures'
      USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM public.commandes WHERE client_id = OLD.client_id) THEN
    RAISE EXCEPTION 'Suppression interdite: client lié à une ou plusieurs commandes'
      USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM public.paiements WHERE client_id = OLD.client_id) THEN
    RAISE EXCEPTION 'Suppression interdite: client lié à un ou plusieurs paiements'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_client_delete ON public.clients;
CREATE TRIGGER trg_guard_client_delete
  BEFORE DELETE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.guard_client_delete();

-- 2. Unicité du dépôt principal (index partiel)
CREATE UNIQUE INDEX IF NOT EXISTS depots_one_principal_idx
  ON public.depots ((is_principal))
  WHERE is_principal = true;

-- 3. Équilibre des écritures comptables
CREATE OR REPLACE FUNCTION public.guard_ecriture_balance()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  v_ecriture_id uuid;
  v_debit numeric;
  v_credit numeric;
BEGIN
  v_ecriture_id := COALESCE(NEW.ecriture_id, OLD.ecriture_id);
  IF v_ecriture_id IS NULL THEN RETURN NULL; END IF;

  SELECT COALESCE(SUM(debit),0), COALESCE(SUM(credit),0)
    INTO v_debit, v_credit
  FROM public.ecriture_lignes
  WHERE ecriture_id = v_ecriture_id;

  -- Tolérance : on n'impose l'équilibre que si l'écriture est validée
  IF EXISTS (
    SELECT 1 FROM public.ecritures_comptables
     WHERE ecriture_id = v_ecriture_id
       AND COALESCE(statut,'brouillon') = 'validee'
  ) AND ABS(v_debit - v_credit) > 0.01 THEN
    RAISE EXCEPTION 'Écriture déséquilibrée: débit=% crédit=%', v_debit, v_credit
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_ecriture_balance ON public.ecriture_lignes;
CREATE CONSTRAINT TRIGGER trg_guard_ecriture_balance
  AFTER INSERT OR UPDATE OR DELETE ON public.ecriture_lignes
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.guard_ecriture_balance();

-- Bloque aussi la validation d'une écriture déséquilibrée
CREATE OR REPLACE FUNCTION public.guard_ecriture_validate()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  v_debit numeric;
  v_credit numeric;
BEGIN
  IF TG_OP = 'UPDATE'
     AND COALESCE(OLD.statut,'brouillon') <> 'validee'
     AND NEW.statut = 'validee' THEN
    SELECT COALESCE(SUM(debit),0), COALESCE(SUM(credit),0)
      INTO v_debit, v_credit
    FROM public.ecriture_lignes WHERE ecriture_id = NEW.ecriture_id;
    IF ABS(v_debit - v_credit) > 0.01 THEN
      RAISE EXCEPTION 'Validation impossible: écriture déséquilibrée (débit=% crédit=%)', v_debit, v_credit
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_ecriture_validate ON public.ecritures_comptables;
CREATE TRIGGER trg_guard_ecriture_validate
  BEFORE UPDATE ON public.ecritures_comptables
  FOR EACH ROW EXECUTE FUNCTION public.guard_ecriture_validate();
