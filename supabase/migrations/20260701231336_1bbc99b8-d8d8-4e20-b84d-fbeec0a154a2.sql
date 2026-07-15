
-- =========================================================
-- Auto-création + synchronisation d'une proforma par commande
-- =========================================================

-- 1. Création automatique d'une proforma à l'insertion d'une commande
CREATE OR REPLACE FUNCTION public.autocreate_proforma_for_commande()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing uuid;
BEGIN
  SELECT proforma_id INTO v_existing
  FROM public.proformas
  WHERE commande_id = NEW.commande_id
  LIMIT 1;

  IF v_existing IS NULL THEN
    INSERT INTO public.proformas (
      client_id, client_nom, commande_id, date_proforma,
      montant_total, statut, notes
    ) VALUES (
      NEW.client_id, NEW.client_nom, NEW.commande_id, COALESCE(NEW.date_commande, CURRENT_DATE),
      COALESCE(NEW.montant_total, 0), 'en_attente',
      'Proforma générée automatiquement depuis ' || NEW.reference
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_autocreate_proforma ON public.commandes;
CREATE TRIGGER trg_autocreate_proforma
AFTER INSERT ON public.commandes
FOR EACH ROW EXECUTE FUNCTION public.autocreate_proforma_for_commande();

-- 2. Maintien à jour des infos client / montant sur la proforma quand la commande change
CREATE OR REPLACE FUNCTION public.sync_proforma_from_commande()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.proformas
  SET client_id     = NEW.client_id,
      client_nom    = NEW.client_nom,
      montant_total = COALESCE(NEW.net_a_payer, NEW.montant_ttc, NEW.montant_total, 0),
      date_proforma = COALESCE(NEW.date_commande, date_proforma),
      updated_at    = now()
  WHERE commande_id = NEW.commande_id
    AND statut = 'en_attente';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_proforma_from_commande ON public.commandes;
CREATE TRIGGER trg_sync_proforma_from_commande
AFTER UPDATE ON public.commandes
FOR EACH ROW EXECUTE FUNCTION public.sync_proforma_from_commande();

-- 3. Synchronisation des lignes commande -> lignes proforma
CREATE OR REPLACE FUNCTION public.sync_proforma_lignes_from_commande()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_commande_id uuid;
  v_proforma_id uuid;
BEGIN
  v_commande_id := COALESCE(NEW.commande_id, OLD.commande_id);

  SELECT proforma_id INTO v_proforma_id
  FROM public.proformas
  WHERE commande_id = v_commande_id
    AND statut = 'en_attente'
  LIMIT 1;

  IF v_proforma_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Rebuild : simple et fiable
  DELETE FROM public.proforma_lignes WHERE proforma_id = v_proforma_id;
  INSERT INTO public.proforma_lignes (proforma_id, produit_id, designation, quantite, prix_unitaire, total_ligne)
  SELECT v_proforma_id, produit_id, designation, quantite, prix_unitaire, COALESCE(total_ht_ligne, total_ligne)
  FROM public.commande_lignes
  WHERE commande_id = v_commande_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_proforma_lignes ON public.commande_lignes;
CREATE TRIGGER trg_sync_proforma_lignes
AFTER INSERT OR UPDATE OR DELETE ON public.commande_lignes
FOR EACH ROW EXECUTE FUNCTION public.sync_proforma_lignes_from_commande();

-- 4. Backfill : générer une proforma pour les commandes existantes qui n'en ont pas
DO $$
DECLARE
  r record;
  v_pro uuid;
BEGIN
  FOR r IN
    SELECT c.*
    FROM public.commandes c
    LEFT JOIN public.proformas p ON p.commande_id = c.commande_id
    WHERE p.proforma_id IS NULL
  LOOP
    INSERT INTO public.proformas (client_id, client_nom, commande_id, date_proforma, montant_total, statut, notes)
    VALUES (r.client_id, r.client_nom, r.commande_id, COALESCE(r.date_commande, CURRENT_DATE),
            COALESCE(r.net_a_payer, r.montant_ttc, r.montant_total, 0), 'en_attente',
            'Proforma générée automatiquement (backfill) depuis ' || r.reference)
    RETURNING proforma_id INTO v_pro;

    INSERT INTO public.proforma_lignes (proforma_id, produit_id, designation, quantite, prix_unitaire, total_ligne)
    SELECT v_pro, produit_id, designation, quantite, prix_unitaire, COALESCE(total_ht_ligne, total_ligne)
    FROM public.commande_lignes
    WHERE commande_id = r.commande_id;
  END LOOP;
END $$;
