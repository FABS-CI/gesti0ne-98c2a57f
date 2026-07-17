CREATE OR REPLACE FUNCTION public.audit_events_by_module(p_days integer DEFAULT 14)
RETURNS TABLE(module text, total bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT COALESCE(a.module,'?'), count(*)::bigint FROM public.audit_logs a
  WHERE a.created_at >= now() - make_interval(days => p_days)
  GROUP BY 1 ORDER BY 2 DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.audit_events_daily(p_days integer DEFAULT 14)
RETURNS TABLE(day date, info bigint, warning bigint, error bigint, total bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT d::date,
    COALESCE((SELECT count(*) FROM public.audit_logs a WHERE date_trunc('day', a.created_at) = d), 0)::bigint,
    0::bigint, 0::bigint,
    COALESCE((SELECT count(*) FROM public.audit_logs a WHERE date_trunc('day', a.created_at) = d), 0)::bigint
  FROM generate_series(current_date - (p_days-1), current_date, interval '1 day') d
  ORDER BY d;
END; $$;

CREATE OR REPLACE FUNCTION public.audit_events_list(
  p_module text DEFAULT NULL, p_period_days integer DEFAULT NULL, p_user_email text DEFAULT NULL,
  p_action text DEFAULT NULL, p_search text DEFAULT NULL, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50)
RETURNS TABLE(id uuid, user_id uuid, action text, module text, entity_type text, entity_id text, details jsonb, created_at timestamp with time zone)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT a.id, a.user_id, a.action, a.module, a.entity_type, a.entity_id, a.details, a.created_at
  FROM public.audit_logs a
  WHERE (p_module IS NULL OR a.module = p_module)
    AND (p_action IS NULL OR a.action = p_action)
    AND (p_period_days IS NULL OR a.created_at >= now() - make_interval(days => p_period_days))
  ORDER BY a.created_at DESC
  LIMIT GREATEST(p_page_size,1) OFFSET GREATEST((p_page-1)*p_page_size, 0);
END; $$;

CREATE OR REPLACE FUNCTION public.audit_events_stats(
  p_module text DEFAULT NULL, p_period_days integer DEFAULT NULL, p_user_email text DEFAULT NULL,
  p_action text DEFAULT NULL, p_search text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN jsonb_build_object('total', COALESCE((SELECT count(*) FROM public.audit_logs), 0));
END; $$;

CREATE OR REPLACE FUNCTION public.audit_finances_anomalies()
RETURNS TABLE(type text, detail text, montant numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT 'facture_zero'::text, f.reference, 0::numeric
  FROM public.factures f WHERE f.montant_total = 0 LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.audit_stats_v2()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN jsonb_build_object(
    'today', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date), 0),
    'week', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date - 7), 0),
    'month', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date - 30), 0),
    'active_users_today', COALESCE((SELECT count(DISTINCT user_id) FROM public.audit_logs WHERE created_at >= current_date AND user_id IS NOT NULL), 0),
    'connected_now', COALESCE((SELECT count(DISTINCT user_id) FROM public.audit_logs WHERE created_at >= now() - interval '15 minutes' AND user_id IS NOT NULL), 0),
    'logins', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='LOGIN' AND created_at >= current_date), 0),
    'logouts', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='LOGOUT' AND created_at >= current_date), 0),
    'login_failed', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='LOGIN_FAILED' AND created_at >= current_date), 0),
    'creations', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='INSERT' AND created_at >= current_date), 0),
    'modifications', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='UPDATE' AND created_at >= current_date), 0),
    'suppressions', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='DELETE' AND created_at >= current_date), 0),
    'impressions', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='PRINT' AND created_at >= current_date), 0),
    'exports_pdf', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='EXPORT' AND (details->>'metadata')::jsonb->>'format' = 'pdf' AND created_at >= current_date), 0),
    'exports_excel', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='EXPORT' AND (details->>'metadata')::jsonb->>'format' IN ('xlsx','csv') AND created_at >= current_date), 0),
    'validations', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='VALIDATION' AND created_at >= current_date), 0),
    'annulations', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action='ANNULATION' AND created_at >= current_date), 0),
    'system_errors', COALESCE((SELECT count(*) FROM public.audit_logs WHERE status='error' AND created_at >= current_date), 0),
    'security_alerts', COALESCE((SELECT count(*) FROM public.security_alerts WHERE acknowledged_at IS NULL), 0)
  );
END; $$;

CREATE OR REPLACE FUNCTION public.audit_stock_anomalies()
RETURNS TABLE(type text, produit_id uuid, depot_id uuid, quantite numeric, detail text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT 'stock_negatif'::text, sd.produit_id, sd.depot_id, sd.quantite, 'Stock négatif'::text
  FROM public.stocks_depots sd WHERE sd.quantite < 0 LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.report_bl_orphelins()
RETURNS TABLE(bl_id uuid, reference text, motif text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT b.bl_id, b.reference, 'Sans commande liée'::text FROM public.bons_livraison b
  WHERE b.commande_id IS NULL LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.report_stock_ecarts()
RETURNS TABLE(produit_id uuid, designation text, ecart numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT il.produit_id, il.designation, il.ecart
  FROM public.inventaire_lignes il WHERE il.ecart <> 0 ORDER BY abs(il.ecart) DESC LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.search_clients_crm(_filters jsonb DEFAULT '{}'::jsonb, _limit integer DEFAULT 50, _offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_q text := _filters->>'q'; v_total bigint; v_items jsonb;
BEGIN
  PERFORM public.assert_permission('clients.voir');
  SELECT count(*) INTO v_total FROM public.clients c
   WHERE (v_q IS NULL OR c.nom ILIKE '%'||v_q||'%' OR COALESCE(c.reference,'') ILIKE '%'||v_q||'%');
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.nom), '[]'::jsonb) INTO v_items FROM (
    SELECT * FROM public.clients c
     WHERE (v_q IS NULL OR c.nom ILIKE '%'||v_q||'%' OR COALESCE(c.reference,'') ILIKE '%'||v_q||'%')
     ORDER BY c.nom LIMIT GREATEST(_limit,1) OFFSET GREATEST(_offset,0)
  ) x;
  RETURN jsonb_build_object('total', v_total, 'items', v_items);
END; $$;

CREATE OR REPLACE FUNCTION public.soft_delete_employe(_employe_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('employes.supprimer');
  UPDATE public.employes SET actif = false, deleted_at = now() WHERE employe_id = _employe_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Employé introuvable'; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.restore_employe(_employe_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('employes.restaurer');
  UPDATE public.employes SET actif = true, deleted_at = NULL WHERE employe_id = _employe_id;
END; $$;