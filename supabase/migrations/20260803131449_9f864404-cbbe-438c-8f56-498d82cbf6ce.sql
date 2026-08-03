
CREATE OR REPLACE FUNCTION public.rbac3_user_depot_set(_user_id uuid, _depot_id uuid, _next boolean)
RETURNS void
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.rbac3_admin_guard();
  IF _next THEN
    INSERT INTO public.user_depots(user_id, depot_id) VALUES (_user_id, _depot_id)
    ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.user_depots WHERE user_id = _user_id AND depot_id = _depot_id;
  END IF;
  PERFORM public.rbac3_log(
    CASE WHEN _next THEN 'scope_depot_ajoute' ELSE 'scope_depot_retire' END,
    'user_depot', _user_id::text, NULL, NULL, NULL,
    jsonb_build_object('depot_id', _depot_id, 'accorde', _next)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac3_user_depots_list()
RETURNS TABLE(user_id uuid, depot_id uuid, principal boolean)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.rbac3_admin_guard();
  RETURN QUERY SELECT ud.user_id, ud.depot_id, ud.principal FROM public.user_depots ud;
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac3_audit_list(_limit integer DEFAULT 200)
RETURNS TABLE(
  id uuid, acteur_email text, action text, cible_type text, cible_id text,
  role_code text, perm_code text, nouvelle_valeur jsonb, created_at timestamptz
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.rbac3_admin_guard();
  RETURN QUERY
    SELECT a.id, a.acteur_email, a.action, a.cible_type, a.cible_id,
           a.role_code, a.perm_code, a.nouvelle_valeur, a.created_at
    FROM public.rbac3_audit a
    ORDER BY a.created_at DESC
    LIMIT LEAST(COALESCE(_limit, 200), 1000);
END;
$$;

REVOKE ALL ON FUNCTION public.rbac3_user_depot_set(uuid, uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_user_depots_list() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_audit_list(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rbac3_user_depot_set(uuid, uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac3_user_depots_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac3_audit_list(integer) TO authenticated;
