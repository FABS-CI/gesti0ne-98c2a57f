-- =========================================================
-- Lot 3 : périmètre dépôt dans les policies RLS
-- =========================================================

-- Helper : accès dépôt en lecture (global scope OU dépôt rattaché OU dépôt nul)
CREATE OR REPLACE FUNCTION public.depot_in_scope(_depot_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL
     AND (
       _depot_id IS NULL
       OR public.is_global_scope(auth.uid())
       OR public.can_access_depot(auth.uid(), _depot_id)
     )
$$;

GRANT EXECUTE ON FUNCTION public.depot_in_scope(uuid) TO authenticated, service_role;

-- ---------- stocks_depots ----------
DROP POLICY IF EXISTS auth_read_stocks_depots ON public.stocks_depots;
DROP POLICY IF EXISTS auth_write_stocks_depots ON public.stocks_depots;
CREATE POLICY stocks_depots_read_scope ON public.stocks_depots
  FOR SELECT TO authenticated USING (public.depot_in_scope(depot_id));
CREATE POLICY stocks_depots_write_scope ON public.stocks_depots
  FOR ALL TO authenticated
  USING (public.depot_in_scope(depot_id))
  WITH CHECK (public.depot_in_scope(depot_id));

-- ---------- stock_mouvements ----------
DROP POLICY IF EXISTS "stock_mvt read auth" ON public.stock_mouvements;
DROP POLICY IF EXISTS "stock_mvt write auth" ON public.stock_mouvements;
CREATE POLICY stock_mouvements_read_scope ON public.stock_mouvements
  FOR SELECT TO authenticated USING (public.depot_in_scope(depot_id));
CREATE POLICY stock_mouvements_write_scope ON public.stock_mouvements
  FOR ALL TO authenticated
  USING (public.depot_in_scope(depot_id))
  WITH CHECK (public.depot_in_scope(depot_id));

-- ---------- inventaires ----------
DROP POLICY IF EXISTS auth_read_inventaires ON public.inventaires;
DROP POLICY IF EXISTS auth_write_inventaires ON public.inventaires;
CREATE POLICY inventaires_read_scope ON public.inventaires
  FOR SELECT TO authenticated USING (public.depot_in_scope(depot_id));
CREATE POLICY inventaires_write_scope ON public.inventaires
  FOR ALL TO authenticated
  USING (public.depot_in_scope(depot_id))
  WITH CHECK (public.depot_in_scope(depot_id));

-- ---------- transferts (source ou destination dans le périmètre) ----------
DROP POLICY IF EXISTS auth_read_transferts ON public.transferts;
DROP POLICY IF EXISTS auth_write_transferts ON public.transferts;
CREATE POLICY transferts_read_scope ON public.transferts
  FOR SELECT TO authenticated
  USING (public.depot_in_scope(depot_source_id) OR public.depot_in_scope(depot_destination_id));
CREATE POLICY transferts_write_scope ON public.transferts
  FOR ALL TO authenticated
  USING (public.depot_in_scope(depot_source_id) OR public.depot_in_scope(depot_destination_id))
  WITH CHECK (public.depot_in_scope(depot_source_id) OR public.depot_in_scope(depot_destination_id));

-- ---------- alertes_stock ----------
DROP POLICY IF EXISTS auth_read_alertes_stock ON public.alertes_stock;
DROP POLICY IF EXISTS auth_write_alertes_stock ON public.alertes_stock;
CREATE POLICY alertes_stock_read_scope ON public.alertes_stock
  FOR SELECT TO authenticated USING (public.depot_in_scope(depot_id));
CREATE POLICY alertes_stock_write_scope ON public.alertes_stock
  FOR ALL TO authenticated
  USING (public.depot_in_scope(depot_id))
  WITH CHECK (public.depot_in_scope(depot_id));

-- ---------- tournees ----------
DROP POLICY IF EXISTS auth_read_tournees ON public.tournees;
DROP POLICY IF EXISTS auth_write_tournees ON public.tournees;
CREATE POLICY tournees_read_scope ON public.tournees
  FOR SELECT TO authenticated USING (public.depot_in_scope(depot_depart_id));
CREATE POLICY tournees_write_scope ON public.tournees
  FOR ALL TO authenticated
  USING (public.depot_in_scope(depot_depart_id))
  WITH CHECK (public.depot_in_scope(depot_depart_id));

-- ---------- depots ----------
DROP POLICY IF EXISTS auth_read_depots ON public.depots;
DROP POLICY IF EXISTS auth_write_depots ON public.depots;
CREATE POLICY depots_read_scope ON public.depots
  FOR SELECT TO authenticated USING (public.depot_in_scope(depot_id));
CREATE POLICY depots_write_scope ON public.depots
  FOR ALL TO authenticated
  USING (public.is_global_scope(auth.uid()) OR public.has_permission(auth.uid(), 'depots.modifier'))
  WITH CHECK (public.is_global_scope(auth.uid()) OR public.has_permission(auth.uid(), 'depots.modifier'));

-- =========================================================
-- Tableau de bord administration sécurité
-- =========================================================
CREATE OR REPLACE FUNCTION public.security_admin_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT public.is_global_scope(auth.uid()) THEN
    RAISE EXCEPTION 'Accès refusé : réservé au super administrateur';
  END IF;

  SELECT jsonb_build_object(
    'users_total', (SELECT count(*) FROM public.profiles),
    'users_actifs', (SELECT count(*) FROM public.profiles WHERE coalesce(statut,'actif') = 'actif'),
    'users_suspendus', (SELECT count(*) FROM public.profiles WHERE statut = 'suspendu'),
    'users_verrouilles', (SELECT count(*) FROM public.profiles WHERE statut = 'verrouille'),
    'roles_total', (SELECT count(*) FROM public.rbac2_roles),
    'permissions_total', (SELECT count(*) FROM public.rbac2_permissions),
    'approbations_en_attente', (SELECT count(*) FROM public.workflow_approvals WHERE statut = 'en_attente'),
    'connexions_24h', (SELECT count(*) FROM public.login_history WHERE created_at > now() - interval '24 hours'),
    'roles_sans_permission', (
      SELECT coalesce(jsonb_agg(r.label ORDER BY r.label), '[]'::jsonb)
      FROM public.rbac2_roles r
      WHERE NOT EXISTS (
        SELECT 1 FROM public.rbac2_role_perms rp
        WHERE rp.role_code = r.code AND rp.granted
      )
    ),
    'utilisateurs_sans_role', (
      SELECT count(*) FROM public.profiles p
      WHERE NOT EXISTS (SELECT 1 FROM public.rbac2_user_roles ur WHERE ur.user_id = p.id)
        AND NOT EXISTS (SELECT 1 FROM public.user_roles ur2 WHERE ur2.user_id = p.id)
    ),
    'dernieres_activites', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT a.created_at, a.action, a.table_name, a.user_email
        FROM public.audit_logs a
        ORDER BY a.created_at DESC
        LIMIT 15
      ) x
    )
  ) INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.security_admin_overview() TO authenticated, service_role;