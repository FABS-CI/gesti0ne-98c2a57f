-- RBAC definitive consistency: action grants must unlock the related screen/view.

CREATE OR REPLACE FUNCTION public.rbac_bulk_set_permissions(
  _role_id uuid,
  _codes text[],
  _accorde boolean
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _affected integer := 0;
  _valid_codes text[];
  _effective_codes text[];
BEGIN
  PERFORM public.assert_permission('roles_permissions.assigner_permission');

  IF _role_id IS NULL OR _codes IS NULL OR array_length(_codes, 1) IS NULL THEN
    RETURN 0;
  END IF;

  SELECT COALESCE(array_agg(DISTINCT p.code), ARRAY[]::text[])
  INTO _valid_codes
  FROM public.rbac_permissions p
  WHERE p.code = ANY(_codes);

  IF array_length(_valid_codes, 1) IS NULL THEN
    RETURN 0;
  END IF;

  IF _accorde THEN
    WITH requested AS (
      SELECT p.code, p.sous_module, p.action
      FROM public.rbac_permissions p
      WHERE p.code = ANY(_valid_codes)
    ), expanded AS (
      SELECT code FROM requested
      UNION
      SELECT p_view.code
      FROM requested r
      JOIN public.rbac_permissions p_view
        ON p_view.sous_module = r.sous_module
       AND p_view.action = 'voir'
      WHERE r.action <> 'voir'
    )
    SELECT COALESCE(array_agg(DISTINCT code), ARRAY[]::text[])
    INTO _effective_codes
    FROM expanded;

    INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
    SELECT _role_id, code, true
    FROM unnest(_effective_codes) AS code
    ON CONFLICT (role_id, permission_code)
    DO UPDATE SET accorde = EXCLUDED.accorde;
    GET DIAGNOSTICS _affected = ROW_COUNT;
  ELSE
    DELETE FROM public.rbac_role_permissions
    WHERE role_id = _role_id
      AND permission_code = ANY(_valid_codes);
    GET DIAGNOSTICS _affected = ROW_COUNT;
  END IF;

  RETURN _affected;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rbac_bulk_set_permissions(uuid, text[], boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.rbac_set_role_permission(
  _role_id uuid,
  _code text,
  _accorde boolean
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF _code IS NULL OR btrim(_code) = '' THEN
    RETURN 0;
  END IF;

  RETURN public.rbac_bulk_set_permissions(_role_id, ARRAY[_code], _accorde);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rbac_set_role_permission(uuid, text, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.trg_rbac_audit_roles()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (
      auth.uid(), v_email, NEW.role_id, NEW.code, 'role_create',
      jsonb_build_object('module', 'roles_permissions', 'new_value', to_jsonb(NEW))
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (
      auth.uid(), v_email, NEW.role_id, NEW.code, 'role_update',
      jsonb_build_object('module', 'roles_permissions', 'old_value', to_jsonb(OLD), 'new_value', to_jsonb(NEW))
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (
      auth.uid(), v_email, OLD.role_id, OLD.code, 'role_delete',
      jsonb_build_object('module', 'roles_permissions', 'old_value', to_jsonb(OLD))
    );
    RETURN OLD;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_rbac_audit_rp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_code text;
  v_perm text;
  v_action text;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = COALESCE(NEW.role_id, OLD.role_id);
  v_perm := COALESCE(NEW.permission_code, OLD.permission_code);

  IF TG_OP = 'INSERT' THEN
    v_action := CASE WHEN NEW.accorde THEN 'permission_add' ELSE 'permission_remove' END;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (
      auth.uid(), v_email, NEW.role_id, v_code, v_action,
      jsonb_build_object('module', 'roles_permissions', 'permission', NEW.permission_code, 'old_value', null, 'new_value', NEW.accorde)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' AND OLD.accorde IS DISTINCT FROM NEW.accorde THEN
    v_action := CASE WHEN NEW.accorde THEN 'permission_add' ELSE 'permission_remove' END;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (
      auth.uid(), v_email, NEW.role_id, v_code, v_action,
      jsonb_build_object('module', 'roles_permissions', 'permission', NEW.permission_code, 'old_value', OLD.accorde, 'new_value', NEW.accorde)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (
      auth.uid(), v_email, OLD.role_id, v_code, 'permission_remove',
      jsonb_build_object('module', 'roles_permissions', 'permission', OLD.permission_code, 'old_value', OLD.accorde, 'new_value', null)
    );
    RETURN OLD;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_rbac_audit_ur()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_code text;
  v_target uuid;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  v_target := COALESCE(NEW.user_id, OLD.user_id);
  SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = COALESCE(NEW.role_id, OLD.role_id);

  INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
  VALUES (
    auth.uid(), v_email, COALESCE(NEW.role_id, OLD.role_id), v_code,
    CASE WHEN TG_OP = 'INSERT' THEN 'role_assign' ELSE 'role_unassign' END,
    jsonb_build_object('module', 'roles_permissions', 'target_user_id', v_target, 'old_value', CASE WHEN TG_OP = 'DELETE' THEN v_code ELSE null END, 'new_value', CASE WHEN TG_OP = 'INSERT' THEN v_code ELSE null END)
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_rbac_roles_audit ON public.rbac_roles;
CREATE TRIGGER trg_rbac_roles_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.rbac_roles
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_roles();

DROP TRIGGER IF EXISTS trg_rbac_rp_audit ON public.rbac_role_permissions;
CREATE TRIGGER trg_rbac_rp_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.rbac_role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_rp();

DROP TRIGGER IF EXISTS trg_rbac_ur_audit ON public.rbac_user_roles;
CREATE TRIGGER trg_rbac_ur_audit
  AFTER INSERT OR DELETE ON public.rbac_user_roles
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_ur();

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
  v_orphan_action_grants int;
BEGIN
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN
    RAISE EXCEPTION 'Forbidden: super_admin requis pour synchroniser le RBAC';
  END IF;

  SELECT COUNT(DISTINCT module), COUNT(DISTINCT sous_module), COUNT(DISTINCT action), COUNT(*)
    INTO v_modules, v_sous_modules, v_actions, v_permissions
    FROM public.rbac_permissions;

  SELECT COUNT(*) FILTER (WHERE actif), COUNT(*)
    INTO v_roles_actifs, v_roles
    FROM public.rbac_roles;

  SELECT COUNT(DISTINCT user_id) INTO v_users FROM public.rbac_user_roles;
  SELECT COUNT(*) INTO v_grants_actuels FROM public.rbac_role_permissions WHERE accorde;

  SELECT COUNT(*) INTO v_missing_default_denied
    FROM public.rbac_roles r
    CROSS JOIN public.rbac_permissions p
    LEFT JOIN public.rbac_role_permissions rp
      ON rp.role_id = r.role_id AND rp.permission_code = p.code
   WHERE r.actif AND rp.role_id IS NULL;

  SELECT COUNT(*) INTO v_orphan_action_grants
  FROM public.rbac_role_permissions rp
  JOIN public.rbac_permissions p ON p.code = rp.permission_code
  WHERE rp.accorde = true
    AND p.action <> 'voir'
    AND NOT EXISTS (
      SELECT 1
      FROM public.rbac_role_permissions rp_view
      JOIN public.rbac_permissions p_view ON p_view.code = rp_view.permission_code
      WHERE rp_view.role_id = rp.role_id
        AND rp_view.accorde = true
        AND p_view.sous_module = p.sous_module
        AND p_view.action = 'voir'
    );

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
    'actions_sans_consultation', v_orphan_action_grants,
    'note', 'Une action accordée ajoute désormais automatiquement la consultation du même sous-module.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_rbac_matrix() TO authenticated;