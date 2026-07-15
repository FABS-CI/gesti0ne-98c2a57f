
-- === Comptabilité (comptabilite.voir) ===

CREATE OR REPLACE FUNCTION public.audit_compta_doublons_paiement()
RETURNS TABLE(facture_id uuid, date_paiement date, mode_paiement text, montant numeric, nb_doublons bigint, paiement_ids uuid[])
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('comptabilite.voir');
  RETURN QUERY
    SELECT p.facture_id, p.date_paiement, p.mode_paiement, p.montant,
           COUNT(*) AS nb_doublons,
           array_agg(p.paiement_id) AS paiement_ids
    FROM public.paiements p
    WHERE p.facture_id IS NOT NULL AND (p.statut IS NULL OR p.statut <> 'annule')
    GROUP BY p.facture_id, p.date_paiement, p.mode_paiement, p.montant
    HAVING COUNT(*) > 1;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.audit_compta_ecritures_desequilibrees()
RETURNS TABLE(ecriture_id uuid, reference text, date_ecriture date, journal text, libelle text, total_debit numeric, total_credit numeric, ecart numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('comptabilite.voir');
  RETURN QUERY
    SELECT e.ecriture_id, e.reference, e.date_ecriture, e.journal, e.libelle,
      COALESCE(SUM(l.debit),0),
      COALESCE(SUM(l.credit),0),
      (COALESCE(SUM(l.debit),0) - COALESCE(SUM(l.credit),0))
    FROM public.ecritures_comptables e
    LEFT JOIN public.ecriture_lignes l ON l.ecriture_id = e.ecriture_id
    GROUP BY e.ecriture_id, e.reference, e.date_ecriture, e.journal, e.libelle
    HAVING COALESCE(SUM(l.debit),0) <> COALESCE(SUM(l.credit),0)
    ORDER BY e.date_ecriture DESC;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.audit_compta_factures_paiements()
RETURNS TABLE(facture_id uuid, reference text, client_nom text, montant_total numeric, montant_paye_enregistre numeric, montant_paye_calcule numeric, ecart numeric, statut text, probleme text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('comptabilite.voir');
  RETURN QUERY
    WITH pay AS (
      SELECT p.facture_id, COALESCE(SUM(p.montant),0) AS total
      FROM public.paiements p
      WHERE p.statut IS NULL OR p.statut <> 'annule'
      GROUP BY p.facture_id
    )
    SELECT f.facture_id, f.reference, f.client_nom,
      f.montant_total,
      COALESCE(f.montant_paye,0),
      COALESCE(p.total,0),
      (COALESCE(p.total,0) - COALESCE(f.montant_paye,0)),
      f.statut,
      CASE
        WHEN COALESCE(p.total,0) > f.montant_total THEN 'SURPAIEMENT'
        WHEN COALESCE(p.total,0) <> COALESCE(f.montant_paye,0) THEN 'MONTANT_PAYE_INCOHERENT'
        WHEN COALESCE(p.total,0) >= f.montant_total AND f.statut NOT IN ('payee','soldee') THEN 'STATUT_INCOHERENT'
        WHEN COALESCE(p.total,0) = 0 AND f.statut IN ('payee','soldee') THEN 'STATUT_INCOHERENT'
        ELSE NULL
      END
    FROM public.factures f
    LEFT JOIN pay p ON p.facture_id = f.facture_id
    WHERE COALESCE(p.total,0) > f.montant_total
       OR COALESCE(p.total,0) <> COALESCE(f.montant_paye,0)
       OR (COALESCE(p.total,0) >= f.montant_total AND f.statut NOT IN ('payee','soldee'))
       OR (COALESCE(p.total,0) = 0 AND f.statut IN ('payee','soldee'))
    ORDER BY ABS(COALESCE(p.total,0) - COALESCE(f.montant_paye,0)) DESC;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.audit_compta_paiements_orphelins()
RETURNS TABLE(paiement_id uuid, reference text, facture_id uuid, montant numeric, date_paiement date, probleme text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('comptabilite.voir');
  RETURN QUERY
    SELECT p.paiement_id, p.reference, p.facture_id, p.montant, p.date_paiement,
      CASE
        WHEN p.facture_id IS NULL THEN 'SANS_FACTURE'
        WHEN f.facture_id IS NULL THEN 'FACTURE_INEXISTANTE'
        WHEN p.montant <= 0 THEN 'MONTANT_INVALIDE'
      END
    FROM public.paiements p
    LEFT JOIN public.factures f ON f.facture_id = p.facture_id
    WHERE p.facture_id IS NULL OR f.facture_id IS NULL OR p.montant <= 0;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.audit_compta_soldes_clients()
RETURNS TABLE(client_id uuid, reference text, nom text, solde_enregistre numeric, solde_calcule numeric, ecart numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('comptabilite.voir');
  RETURN QUERY
    WITH fac AS (
      SELECT f.client_id,
             COALESCE(SUM(f.montant_total),0) AS tot_fac,
             COALESCE(SUM(f.montant_paye),0)  AS tot_pay
      FROM public.factures f
      WHERE f.statut IS NULL OR f.statut <> 'annulee'
      GROUP BY f.client_id
    )
    SELECT c.client_id, c.reference, c.nom,
      COALESCE(c.solde,0),
      (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0)),
      (COALESCE(c.solde,0) - (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0)))
    FROM public.clients c
    LEFT JOIN fac f ON f.client_id = c.client_id
    WHERE COALESCE(c.solde,0) <> (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0))
    ORDER BY ABS(COALESCE(c.solde,0) - (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0))) DESC;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.audit_finances_anomalies()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_desequilibrees int; v_factures_pb int; v_soldes_pb int;
  v_orphelins int; v_doublons int;
  v_total_ecritures int; v_total_paiements int; v_total_factures int;
BEGIN
  PERFORM public.assert_permission('comptabilite.voir');
  SELECT COUNT(*) INTO v_desequilibrees FROM public.audit_compta_ecritures_desequilibrees();
  SELECT COUNT(*) INTO v_factures_pb FROM public.audit_compta_factures_paiements();
  SELECT COUNT(*) INTO v_soldes_pb FROM public.audit_compta_soldes_clients();
  SELECT COUNT(*) INTO v_orphelins FROM public.audit_compta_paiements_orphelins();
  SELECT COUNT(*) INTO v_doublons FROM public.audit_compta_doublons_paiement();
  SELECT COUNT(*) INTO v_total_ecritures FROM public.ecritures_comptables;
  SELECT COUNT(*) INTO v_total_paiements FROM public.paiements;
  SELECT COUNT(*) INTO v_total_factures FROM public.factures;
  RETURN jsonb_build_object(
    'generated_at', now(),
    'total_ecritures', v_total_ecritures,
    'total_factures', v_total_factures,
    'total_paiements', v_total_paiements,
    'ecritures_desequilibrees', v_desequilibrees,
    'factures_incoherentes', v_factures_pb,
    'soldes_clients_incoherents', v_soldes_pb,
    'paiements_orphelins', v_orphelins,
    'doublons_paiement', v_doublons,
    'verdict', CASE
      WHEN v_desequilibrees=0 AND v_factures_pb=0 AND v_soldes_pb=0 AND v_orphelins=0 AND v_doublons=0
      THEN 'GO_PRODUCTION' ELSE 'ANOMALIES_DETECTEES' END
  );
END;
$fn$;

-- === Stock (stock.voir_audit) ===

CREATE OR REPLACE FUNCTION public.audit_stock_anomalies()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_stock_negatif int; v_mvts_sans_produit int; v_mvts_sans_user int;
  v_doublons int; v_total_produits int; v_total_mvts bigint;
BEGIN
  PERFORM public.assert_permission('stock.voir_audit');
  SELECT COUNT(*) INTO v_stock_negatif FROM public.stocks_depots WHERE quantite < 0;
  SELECT COUNT(*) INTO v_mvts_sans_produit
    FROM public.stock_mouvements m
    LEFT JOIN public.produits p ON p.produit_id = m.produit_id
    WHERE p.produit_id IS NULL;
  SELECT COUNT(*) INTO v_mvts_sans_user
    FROM public.stock_mouvements
    WHERE user_id IS NULL AND created_at > now() - interval '90 days';
  SELECT COUNT(*) INTO v_doublons FROM (
    SELECT origine, document_id, produit_id, type, COUNT(*) c
    FROM public.stock_mouvements
    WHERE document_id IS NOT NULL AND origine IS NOT NULL
    GROUP BY 1,2,3,4 HAVING COUNT(*) > 1
  ) d;
  SELECT COUNT(*) INTO v_total_produits FROM public.produits;
  SELECT COUNT(*) INTO v_total_mvts FROM public.stock_mouvements;
  RETURN jsonb_build_object(
    'generated_at', now(),
    'total_produits', v_total_produits,
    'total_mouvements', v_total_mvts,
    'ecarts_stock', 0,
    'stock_negatif', v_stock_negatif,
    'mouvements_orphelins_produit', v_mvts_sans_produit,
    'mouvements_sans_utilisateur_90j', v_mvts_sans_user,
    'doublons_document', v_doublons,
    'verdict', CASE
      WHEN v_stock_negatif = 0 AND v_mvts_sans_produit = 0 AND v_doublons = 0
      THEN 'GO_PRODUCTION' ELSE 'ANOMALIES_DETECTEES' END
  );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.report_stock_ecarts()
RETURNS TABLE(produit_id uuid, titre text, stock_actuel integer, stock_calcule integer, ecart integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('stock.voir_audit');
  RETURN QUERY
    SELECT p.produit_id, p.titre,
           COALESCE(p.stock,0)::int,
           COALESCE(SUM(m.quantite),0)::int,
           (COALESCE(p.stock,0) - COALESCE(SUM(m.quantite),0))::int
    FROM public.produits p
    LEFT JOIN public.stock_mouvements m ON m.produit_id = p.produit_id
    GROUP BY p.produit_id, p.titre, p.stock
    HAVING (COALESCE(p.stock,0) - COALESCE(SUM(m.quantite),0)) <> 0
    ORDER BY ABS(COALESCE(p.stock,0) - COALESCE(SUM(m.quantite),0)) DESC
    LIMIT 500;
END;
$fn$;

-- === Livraisons (livraisons.voir) ===

CREATE OR REPLACE FUNCTION public.report_bl_orphelins()
RETURNS TABLE(bl_id uuid, reference text, statut text, client_id uuid, montant numeric, cree_le timestamp with time zone)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('livraisons.voir');
  RETURN QUERY
    SELECT bl.bl_id, bl.reference, bl.statut::text, bl.client_id, bl.montant_total, bl.created_at
    FROM public.bons_livraison bl
    WHERE bl.commande_id IS NULL
    ORDER BY bl.created_at DESC;
END;
$fn$;

-- === Audit journal (audit.voir) ===

CREATE OR REPLACE FUNCTION public.audit_events_by_module(p_days integer DEFAULT 30)
RETURNS TABLE(module text, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
    SELECT COALESCE(NULLIF(e.module,''), e.table_name) AS module, COUNT(*) AS total
    FROM public.audit_events e
    WHERE e.occurred_at >= now() - (p_days || ' days')::interval
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 12;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.audit_events_daily(p_days integer DEFAULT 30)
RETURNS TABLE(day date, info bigint, warning bigint, critical bigint, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
    WITH days AS (
      SELECT generate_series(
        (current_date - (p_days - 1))::date,
        current_date,
        interval '1 day'
      )::date AS day
    )
    SELECT d.day,
      COUNT(*) FILTER (WHERE COALESCE(e.criticite::text,'info') = 'info'),
      COUNT(*) FILTER (WHERE e.criticite::text = 'warning'),
      COUNT(*) FILTER (WHERE e.criticite::text = 'critical'),
      COUNT(e.id)
    FROM days d
    LEFT JOIN public.audit_events e ON e.occurred_at::date = d.day
    GROUP BY d.day
    ORDER BY d.day;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.audit_stats_v2()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_result jsonb;
BEGIN
  PERFORM public.assert_permission('audit.voir');
  WITH e AS (
    SELECT * FROM public.audit_events
    WHERE occurred_at >= now() - interval '90 days'
  )
  SELECT jsonb_build_object(
    'today',              (SELECT count(*) FROM e WHERE occurred_at::date = current_date),
    'week',               (SELECT count(*) FROM e WHERE occurred_at >= date_trunc('week', now())),
    'month',              (SELECT count(*) FROM e WHERE occurred_at >= date_trunc('month', now())),
    'active_users_today', (SELECT count(DISTINCT user_id) FROM e WHERE occurred_at::date = current_date),
    'connected_now',      (SELECT count(DISTINCT user_id) FROM e WHERE occurred_at >= now() - interval '15 minutes'),
    'logins',             (SELECT count(*) FROM e WHERE action = 'LOGIN'),
    'logouts',            (SELECT count(*) FROM e WHERE action = 'LOGOUT'),
    'login_failed',       (SELECT count(*) FROM e WHERE action = 'LOGIN_FAILED'),
    'creations',          (SELECT count(*) FROM e WHERE action = 'INSERT'),
    'modifications',      (SELECT count(*) FROM e WHERE action = 'UPDATE'),
    'suppressions',       (SELECT count(*) FROM e WHERE action = 'DELETE'),
    'impressions',        (SELECT count(*) FROM e WHERE action = 'PRINT'),
    'exports_pdf',        (SELECT count(*) FROM e WHERE action = 'EXPORT' AND (metadata->>'format') ILIKE 'pdf'),
    'exports_excel',      (SELECT count(*) FROM e WHERE action = 'EXPORT' AND (metadata->>'format') ILIKE ANY (ARRAY['xlsx','excel','csv'])),
    'validations',        (SELECT count(*) FROM e WHERE action IN ('VALIDATION','APPROBATION')),
    'annulations',        (SELECT count(*) FROM e WHERE action = 'ANNULATION'),
    'system_errors',      (SELECT count(*) FROM e WHERE status = 'error'),
    'security_alerts',    (SELECT count(*) FROM public.security_alerts WHERE acknowledged_at IS NULL)
  ) INTO v_result;
  RETURN v_result;
END;
$fn$;

-- === Clients (clients.voir) ===

CREATE OR REPLACE FUNCTION public.dashboard_client_stats()
RETURNS TABLE(total bigint, actifs bigint, solde_total numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('clients.voir');
  RETURN QUERY
    SELECT count(*)::bigint,
           count(*) FILTER (WHERE c.actif)::bigint,
           COALESCE(sum(c.solde), 0)::numeric
    FROM public.clients c;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.report_client_duplicates()
RETURNS TABLE(nom_normalise text, nb integer, client_ids uuid[], noms text[])
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
BEGIN
  PERFORM public.assert_permission('clients.voir');
  RETURN QUERY
    SELECT LOWER(TRIM(c.nom)), COUNT(*)::int,
           array_agg(c.client_id ORDER BY c.created_at),
           array_agg(c.nom ORDER BY c.created_at)
    FROM public.clients c
    WHERE c.nom IS NOT NULL AND TRIM(c.nom) <> ''
    GROUP BY 1 HAVING COUNT(*) > 1
    ORDER BY 2 DESC, 1;
END;
$fn$;
