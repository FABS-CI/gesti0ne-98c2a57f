-- 1) Verrouiller les fonctions e2e_* (tests uniquement, jamais appelables en prod)
REVOKE EXECUTE ON FUNCTION public.e2e_seed()                       FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.e2e_reset()                      FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.e2e_get_bl()                     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.e2e_get_facture()                FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.e2e_set_colis_livre(integer)     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.e2e_set_facture_paye(numeric)    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.e2e_set_facture_statut(text)     FROM PUBLIC, anon, authenticated;

-- 2) Vue monitoring : erreurs RPC / actions récentes
CREATE OR REPLACE VIEW public.v_rpc_errors_recent
WITH (security_invoker = true)
AS
SELECT
  id,
  occurred_at,
  user_id,
  action,
  table_name,
  record_id,
  status,
  error_message,
  duration_ms,
  metadata
FROM public.audit_events
WHERE status <> 'success'
  AND occurred_at > now() - interval '7 days'
ORDER BY occurred_at DESC
LIMIT 500;

GRANT SELECT ON public.v_rpc_errors_recent TO authenticated;
-- Note : la vue étant en security_invoker, la RLS de audit_events s'applique
-- (SELECT réservé à super_admin / directeur_general).

COMMENT ON VIEW public.v_rpc_errors_recent IS
  'Monitoring : 500 dernières erreurs RPC/action (7j). Lecture via RLS audit_events (super_admin, directeur_general).';