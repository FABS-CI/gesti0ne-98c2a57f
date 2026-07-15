
-- Lot 1: Audit lecture seule du module Stock (aucune modification de données)

CREATE OR REPLACE FUNCTION public.audit_stock_coherence()
RETURNS TABLE (
  produit_id uuid,
  reference text,
  titre text,
  stock_enregistre integer,
  stock_calcule integer,
  ecart integer,
  nb_mouvements bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.produit_id,
    p.reference,
    p.titre,
    COALESCE(p.stock, 0) AS stock_enregistre,
    COALESCE(SUM(m.quantite_entree - m.quantite_sortie), 0)::int AS stock_calcule,
    (COALESCE(p.stock, 0) - COALESCE(SUM(m.quantite_entree - m.quantite_sortie), 0))::int AS ecart,
    COUNT(m.mouvement_id) AS nb_mouvements
  FROM public.produits p
  LEFT JOIN public.stock_mouvements m ON m.produit_id = p.produit_id
  GROUP BY p.produit_id, p.reference, p.titre, p.stock
  HAVING COALESCE(p.stock, 0) <> COALESCE(SUM(m.quantite_entree - m.quantite_sortie), 0)
  ORDER BY ABS(COALESCE(p.stock, 0) - COALESCE(SUM(m.quantite_entree - m.quantite_sortie), 0)) DESC;
$$;

REVOKE ALL ON FUNCTION public.audit_stock_coherence() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.audit_stock_coherence() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.audit_stock_anomalies()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ecarts int;
  v_stock_negatif int;
  v_mvts_sans_produit int;
  v_mvts_sans_user int;
  v_doublons int;
  v_total_produits int;
  v_total_mvts bigint;
BEGIN
  SELECT COUNT(*) INTO v_ecarts FROM public.audit_stock_coherence();

  SELECT COUNT(*) INTO v_stock_negatif
  FROM public.produits WHERE stock < 0;

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
    'ecarts_stock', v_ecarts,
    'stock_negatif', v_stock_negatif,
    'mouvements_orphelins_produit', v_mvts_sans_produit,
    'mouvements_sans_utilisateur_90j', v_mvts_sans_user,
    'doublons_document', v_doublons,
    'verdict', CASE
      WHEN v_ecarts = 0 AND v_stock_negatif = 0 AND v_mvts_sans_produit = 0 AND v_doublons = 0
      THEN 'GO_PRODUCTION'
      ELSE 'ANOMALIES_DETECTEES'
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.audit_stock_anomalies() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.audit_stock_anomalies() TO authenticated, service_role;
