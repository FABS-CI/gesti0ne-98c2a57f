
-- Fonction : force exercice_id = actif si NULL à la création
CREATE OR REPLACE FUNCTION public.set_default_exercice_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actif uuid;
BEGIN
  IF NEW.exercice_id IS NULL THEN
    SELECT exercice_id INTO v_actif
    FROM public.exercices
    WHERE is_actif = true
    LIMIT 1;
    IF v_actif IS NULL THEN
      RAISE EXCEPTION 'Aucun exercice actif : impossible de créer ce document.'
        USING ERRCODE = 'check_violation';
    END IF;
    NEW.exercice_id := v_actif;
  END IF;
  RETURN NEW;
END;
$$;

-- Fonction : bloque toute écriture sur un exercice clôturé/archivé
CREATE OR REPLACE FUNCTION public.prevent_write_on_closed_exercice()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_statut public.exercice_statut;
  v_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_id := OLD.exercice_id;
  ELSE
    v_id := NEW.exercice_id;
    -- Empêcher aussi de déplacer une ligne DEPUIS un exercice clôturé
    IF TG_OP = 'UPDATE' AND OLD.exercice_id IS DISTINCT FROM NEW.exercice_id THEN
      SELECT statut INTO v_statut FROM public.exercices WHERE exercice_id = OLD.exercice_id;
      IF v_statut IN ('cloture', 'archive') THEN
        RAISE EXCEPTION 'Exercice source clôturé : modification interdite.'
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;

  IF v_id IS NULL THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  SELECT statut INTO v_statut FROM public.exercices WHERE exercice_id = v_id;
  IF v_statut IN ('cloture', 'archive') THEN
    RAISE EXCEPTION 'Exercice % : écriture interdite (statut %).', v_id, v_statut
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

-- Attache les triggers sur toutes les tables métier avec exercice_id
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'achats','bons_livraison','bons_retour','bulletins_paie','commandes',
    'ecritures_comptables','factures','inventaires','paiements','proformas',
    'retours','stock_mouvements','transactions'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_set_default_exercice ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_set_default_exercice BEFORE INSERT ON public.%I
       FOR EACH ROW EXECUTE FUNCTION public.set_default_exercice_id()', t);

    EXECUTE format('DROP TRIGGER IF EXISTS trg_prevent_write_closed_exercice ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_prevent_write_closed_exercice
       BEFORE INSERT OR UPDATE OR DELETE ON public.%I
       FOR EACH ROW EXECUTE FUNCTION public.prevent_write_on_closed_exercice()', t);
  END LOOP;
END $$;
