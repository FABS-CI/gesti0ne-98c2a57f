
CREATE OR REPLACE FUNCTION public.sync_rbac_matrix()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_modules int;
  v_sous_modules int;
  v_actions int;
  v_permissions int;
  v_roles int;
  v_roles_actifs int;
  v_users int;
  v_missing_default_denied int;
  v_grants_actuels int;
BEGIN
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN
    RAISE EXCEPTION 'Forbidden: super_admin requis pour synchroniser le RBAC';
  END IF;

  SELECT COUNT(DISTINCT module),
         COUNT(DISTINCT sous_module),
         COUNT(DISTINCT action),
         COUNT(*)
    INTO v_modules, v_sous_modules, v_actions, v_permissions
    FROM public.rbac_permissions;

  SELECT COUNT(*) FILTER (WHERE actif),
         COUNT(*)
    INTO v_roles_actifs, v_roles
    FROM public.rbac_roles;

  SELECT COUNT(DISTINCT user_id) INTO v_users FROM public.rbac_user_roles;

  SELECT COUNT(*) INTO v_grants_actuels
    FROM public.rbac_role_permissions WHERE accorde;

  -- Entrées qui apparaîtront comme "Refusé" par défaut dans la matrice
  -- (pas d'insertion : le modèle ne stocke que les autorisations accordées,
  -- l'absence de ligne = refus. Rien n'est écrasé.)
  SELECT COUNT(*) INTO v_missing_default_denied
    FROM public.rbac_roles r
    CROSS JOIN public.rbac_permissions p
    LEFT JOIN public.rbac_role_permissions rp
      ON rp.role_id = r.role_id AND rp.permission_code = p.code
   WHERE r.actif AND rp.role_id IS NULL;

  RETURN jsonb_build_object(
    'timestamp', now(),
    'modules', v_modules,
    'sous_modules', v_sous_modules,
    'actions', v_actions,
    'permissions', v_permissions,
    'roles_total', v_roles,
    'roles_actifs', v_roles_actifs,
    'utilisateurs_avec_role', v_users,
    'autorisations_accordees', v_grants_actuels,
    'entrees_refusees_par_defaut', v_missing_default_denied,
    'note', 'Aucune permission écrasée. Les nouvelles entrées apparaissent comme Refusé et doivent être accordées manuellement.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_rbac_matrix() TO authenticated;
