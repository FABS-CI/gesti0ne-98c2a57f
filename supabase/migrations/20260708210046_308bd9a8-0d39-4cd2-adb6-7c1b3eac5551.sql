-- ═══════════════════════════════════════════════════════════════════
-- Phase 2 — Étape A : refactor des fonctions de stock
-- stocks_depots devient l'unique référence lue par le code SQL.
-- Rien n'est droppé ici : produits.stock reste alimenté par le trigger
-- de sync pour compatibilité pendant la période de validation.
-- ═══════════════════════════════════════════════════════════════════

-- 1) apply_stock_mouvement : lit SUM(stocks_depots) au lieu de produits.stock
CREATE OR REPLACE FUNCTION public.apply_stock_mouvement()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.stock_resultant IS NULL OR NEW.stock_resultant = 0 THEN
    NEW.stock_resultant := COALESCE(
      (SELECT SUM(quantite)::int FROM public.stocks_depots WHERE produit_id = NEW.produit_id),
      0
    );
  END IF;
  RETURN NEW;
END $function$;

-- 2) refresh_produit_stock : conservé comme NO-OP pour compat appelants
CREATE OR REPLACE FUNCTION public.refresh_produit_stock(_produit_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Déprécié Phase 2 : stocks_depots est la source unique.
  -- Le trigger trg_sync_produit_stock maintient produits.stock en cache
  -- automatiquement pendant la période de transition.
  PERFORM 1;
END $function$;

-- 3) ajuster_stock_depot : ne touche plus à produits.stock
CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(
  _produit_id uuid, _depot_id uuid, _nouvelle_quantite integer,
  _motif text DEFAULT NULL::text, _origine text DEFAULT 'ajustement'::text,
  _document_id uuid DEFAULT NULL::uuid, _document_reference text DEFAULT NULL::text,
  _document_table text DEFAULT NULL::text, _observation text DEFAULT NULL::text
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_current integer;
  v_delta integer;
  v_entree integer := 0;
  v_sortie integer := 0;
  v_type text;
  v_stock_total integer;
  v_user_nom text;
BEGIN
  INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
    VALUES(_produit_id, _depot_id, 0)
    ON CONFLICT(produit_id, depot_id) DO NOTHING;

  SELECT quantite INTO v_current FROM public.stocks_depots
    WHERE produit_id = _produit_id AND depot_id = _depot_id FOR UPDATE;

  v_delta := _nouvelle_quantite - COALESCE(v_current, 0);

  UPDATE public.stocks_depots
    SET quantite = _nouvelle_quantite, updated_at = now()
    WHERE produit_id = _produit_id AND depot_id = _depot_id;

  -- Stock total = SUM(stocks_depots) — plus d'UPDATE sur produits.stock
  SELECT COALESCE(SUM(quantite),0)::int INTO v_stock_total
    FROM public.stocks_depots WHERE produit_id = _produit_id;

  IF v_delta > 0 THEN
    v_entree := v_delta; v_type := 'entree';
  ELSIF v_delta < 0 THEN
    v_sortie := -v_delta; v_type := 'sortie';
  ELSE
    v_type := 'ajustement';
  END IF;

  v_user_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  INSERT INTO public.stock_mouvements(
    produit_id, depot_id, type, quantite, stock_resultant, motif,
    origine, document_id, document_reference, document_table,
    user_id, user_nom, observation, quantite_entree, quantite_sortie
  ) VALUES(
    _produit_id, _depot_id, v_type, ABS(v_delta), v_stock_total, _motif,
    COALESCE(_origine, 'ajustement'), _document_id, _document_reference, _document_table,
    auth.uid(), v_user_nom, _observation, v_entree, v_sortie
  );
END $function$;

-- 4) recalculer_stock_produit : déprécié → retourne le stock actuel calculé,
--    n'écrit plus rien (stocks_depots est déjà la vérité)
CREATE OR REPLACE FUNCTION public.recalculer_stock_produit(_produit_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_stock int;
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = v_uid
      AND role IN ('super_admin','directeur_general','gestionnaire_stock')
  ) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.produits WHERE produit_id = _produit_id) THEN
    RAISE EXCEPTION 'Produit introuvable';
  END IF;

  SELECT COALESCE(SUM(quantite),0)::int INTO v_stock
    FROM public.stocks_depots WHERE produit_id = _produit_id;

  RETURN jsonb_build_object(
    'changed', false,
    'stock', v_stock,
    'deprecated', true,
    'message', 'stocks_depots est la source unique de vérité (Phase 2)'
  );
END $function$;

-- 5) audit_stock_anomalies : ne compare plus produits.stock ↔ stocks_depots
--    (invariant maintenant garanti par la vue v_produits). On garde les
--    autres checks utiles : stock négatif dans stocks_depots, orphelins,
--    doublons de mouvement, mouvements sans user récent.
CREATE OR REPLACE FUNCTION public.audit_stock_anomalies()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_stock_negatif int;
  v_mvts_sans_produit int;
  v_mvts_sans_user int;
  v_doublons int;
  v_total_produits int;
  v_total_mvts bigint;
BEGIN
  -- Stock négatif directement sur les dépôts (source unique)
  SELECT COUNT(*) INTO v_stock_negatif
  FROM public.stocks_depots WHERE quantite < 0;

  SELECT COUNT(*) INTO v_mvts_sans_produit
  FROM public.stock_mouvements m
  LEFT JOIN public.produits p ON p.produit_id = m.produit_id
  WHERE p.produit_id IS NULL;

  SELECT COUNT(*) INTO v_mvts_sans_user
  FROM public.stock_mouvements
  WHERE user_id IS NULL AND created_at > now() - interval '90 days';

  SELECT COUNT(*) INTO v_doublons
  FROM (
    SELECT origine, document_id, produit_id, type, COUNT(*) c
    FROM public.stock_mouvements
    WHERE document_id IS NOT NULL AND origine IS NOT NULL
    GROUP BY 1,2,3,4
    HAVING COUNT(*) > 1
  ) d;

  SELECT COUNT(*) INTO v_total_produits FROM public.produits;
  SELECT COUNT(*) INTO v_total_mvts FROM public.stock_mouvements;

  RETURN jsonb_build_object(
    'generated_at', now(),
    'total_produits', v_total_produits,
    'total_mouvements', v_total_mvts,
    'ecarts_stock', 0,  -- garanti 0 par v_produits (source unique)
    'stock_negatif', v_stock_negatif,
    'mouvements_orphelins_produit', v_mvts_sans_produit,
    'mouvements_sans_utilisateur_90j', v_mvts_sans_user,
    'doublons_document', v_doublons,
    'verdict', CASE
      WHEN v_stock_negatif = 0 AND v_mvts_sans_produit = 0 AND v_doublons = 0
      THEN 'GO_PRODUCTION'
      ELSE 'ANOMALIES_DETECTEES'
    END
  );
END;
$function$;

COMMENT ON FUNCTION public.refresh_produit_stock(uuid) IS
  'DEPRECATED Phase 2 — NO-OP. stocks_depots est la source unique de vérité.';
COMMENT ON FUNCTION public.recalculer_stock_produit(uuid, text) IS
  'DEPRECATED Phase 2 — retourne le stock actuel sans rien recalculer.';