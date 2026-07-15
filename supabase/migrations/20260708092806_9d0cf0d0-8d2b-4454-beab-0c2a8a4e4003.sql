
-- =====================================================================
-- LOT 2: Verrous & contraintes
-- =====================================================================

-- 2.1 Interdire la suppression d'un mouvement de stock
CREATE OR REPLACE FUNCTION public.trg_stock_mouvements_no_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- service_role peut supprimer (maintenance système uniquement)
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'Suppression interdite : un mouvement de stock validé ne peut pas être supprimé (mouvement_id=%)', OLD.mouvement_id
    USING ERRCODE = 'insufficient_privilege';
END;
$$;

DROP TRIGGER IF EXISTS trg_stock_mouvements_no_delete ON public.stock_mouvements;
CREATE TRIGGER trg_stock_mouvements_no_delete
BEFORE DELETE ON public.stock_mouvements
FOR EACH ROW EXECUTE FUNCTION public.trg_stock_mouvements_no_delete();

-- 2.2 Interdire la modification d'un inventaire validé/régularisé
CREATE OR REPLACE FUNCTION public.trg_inventaires_lock_valide()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.statut IN ('valide', 'regularise')
     AND NEW.statut = OLD.statut
     AND current_setting('request.jwt.claims', true)::jsonb->>'role' <> 'service_role' THEN
    -- Autoriser uniquement le passage valide -> regularise ou -> annule
    IF NEW.statut NOT IN ('regularise', 'annule') OR OLD.statut = 'regularise' THEN
      RAISE EXCEPTION 'Modification interdite : inventaire % déjà %.', OLD.numero, OLD.statut
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventaires_lock_valide ON public.inventaires;
CREATE TRIGGER trg_inventaires_lock_valide
BEFORE UPDATE ON public.inventaires
FOR EACH ROW EXECUTE FUNCTION public.trg_inventaires_lock_valide();

-- 2.3 Verrou transactionnel + anti-doublon avant chaque mouvement
CREATE OR REPLACE FUNCTION public.trg_stock_mouvements_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_exists boolean;
BEGIN
  -- Verrou pessimiste sur la ligne produit (empêche 2 sorties simultanées)
  PERFORM 1 FROM public.produits WHERE produit_id = NEW.produit_id FOR UPDATE;

  -- Anti-doublon : un même document ne peut pas générer 2 mouvements identiques
  IF NEW.origine IS NOT NULL AND NEW.document_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.stock_mouvements
      WHERE origine = NEW.origine
        AND document_id = NEW.document_id
        AND produit_id = NEW.produit_id
        AND type = NEW.type
    ) INTO v_exists;
    IF v_exists THEN
      RAISE EXCEPTION 'Doublon détecté : mouvement % déjà enregistré pour le document % (produit %)',
        NEW.type, NEW.document_id, NEW.produit_id
        USING ERRCODE = 'unique_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stock_mouvements_guard ON public.stock_mouvements;
CREATE TRIGGER trg_stock_mouvements_guard
BEFORE INSERT ON public.stock_mouvements
FOR EACH ROW EXECUTE FUNCTION public.trg_stock_mouvements_guard();


-- =====================================================================
-- LOT 3: Recalcul automatique
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.stock_corrections_audit (
  correction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id) ON DELETE CASCADE,
  stock_avant integer NOT NULL,
  stock_apres integer NOT NULL,
  ecart integer NOT NULL,
  nb_mouvements bigint NOT NULL,
  motif text,
  corrige_par uuid REFERENCES auth.users(id),
  corrige_par_nom text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.stock_corrections_audit TO authenticated;
GRANT ALL ON public.stock_corrections_audit TO service_role;

ALTER TABLE public.stock_corrections_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins read corrections" ON public.stock_corrections_audit;
CREATE POLICY "admins read corrections" ON public.stock_corrections_audit
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid()
      AND role IN ('super_admin','directeur_general','gestionnaire_stock','comptable')
  )
);

CREATE INDEX IF NOT EXISTS idx_stock_corrections_produit ON public.stock_corrections_audit(produit_id, created_at DESC);

-- Recalcule le stock d'un produit et journalise l'écart
CREATE OR REPLACE FUNCTION public.recalculer_stock_produit(_produit_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock_avant int;
  v_stock_calcule int;
  v_nb bigint;
  v_uid uuid;
  v_nom text;
BEGIN
  v_uid := auth.uid();

  -- Autorisation
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = v_uid
      AND role IN ('super_admin','directeur_general','gestionnaire_stock')
  ) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT p.stock INTO v_stock_avant
  FROM public.produits p
  WHERE p.produit_id = _produit_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Produit introuvable';
  END IF;

  SELECT COALESCE(SUM(quantite_entree - quantite_sortie), 0)::int,
         COUNT(*)
    INTO v_stock_calcule, v_nb
  FROM public.stock_mouvements
  WHERE produit_id = _produit_id;

  IF v_stock_avant = v_stock_calcule THEN
    RETURN jsonb_build_object('changed', false, 'stock', v_stock_avant);
  END IF;

  SELECT COALESCE(nom_complet, email) INTO v_nom
  FROM public.profiles WHERE id = v_uid;

  UPDATE public.produits
     SET stock = v_stock_calcule,
         updated_at = now()
   WHERE produit_id = _produit_id;

  INSERT INTO public.stock_corrections_audit
    (produit_id, stock_avant, stock_apres, ecart, nb_mouvements, motif, corrige_par, corrige_par_nom)
  VALUES
    (_produit_id, v_stock_avant, v_stock_calcule, v_stock_calcule - v_stock_avant, v_nb, _motif, v_uid, v_nom);

  RETURN jsonb_build_object(
    'changed', true,
    'stock_avant', v_stock_avant,
    'stock_apres', v_stock_calcule,
    'ecart', v_stock_calcule - v_stock_avant,
    'nb_mouvements', v_nb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.recalculer_stock_produit(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.recalculer_stock_produit(uuid, text) TO authenticated;

-- Recalcule tous les produits présentant un écart
CREATE OR REPLACE FUNCTION public.recalculer_stock_global(_motif text DEFAULT 'Recalcul global')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_corriges int := 0;
  v_ecart_total int := 0;
  r record;
  res jsonb;
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = v_uid AND role IN ('super_admin','directeur_general')
  ) THEN
    RAISE EXCEPTION 'Accès refusé (super_admin ou directeur_general requis)';
  END IF;

  FOR r IN SELECT produit_id FROM public.audit_stock_coherence() LOOP
    res := public.recalculer_stock_produit(r.produit_id, _motif);
    IF (res->>'changed')::boolean THEN
      v_corriges := v_corriges + 1;
      v_ecart_total := v_ecart_total + ABS((res->>'ecart')::int);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'corriges', v_corriges,
    'ecart_absolu_total', v_ecart_total,
    'terminated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.recalculer_stock_global(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.recalculer_stock_global(text) TO authenticated;
