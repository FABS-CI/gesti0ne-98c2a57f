CREATE OR REPLACE FUNCTION public.rbac_request_headers()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw text;
BEGIN
  v_raw := current_setting('request.headers', true);
  IF v_raw IS NULL OR btrim(v_raw) = '' THEN
    RETURN '{}'::jsonb;
  END IF;
  RETURN v_raw::jsonb;
EXCEPTION WHEN others THEN
  RETURN '{}'::jsonb;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rbac_request_headers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rbac_request_headers() TO authenticated;

CREATE OR REPLACE FUNCTION public.trg_rbac_audit_roles()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_headers jsonb;
  v_user_agent text;
  v_ip text;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  v_headers := public.rbac_request_headers();
  v_user_agent := v_headers ->> 'user-agent';
  v_ip := COALESCE(v_headers ->> 'x-forwarded-for', v_headers ->> 'cf-connecting-ip', v_headers ->> 'x-real-ip');

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, ip, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, NEW.code, 'role_create', jsonb_build_object('module', 'roles_permissions'), v_ip, v_user_agent, NULL, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, ip, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, NEW.code, 'role_update', jsonb_build_object('module', 'roles_permissions'), v_ip, v_user_agent, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, ip, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, OLD.role_id, OLD.code, 'role_delete', jsonb_build_object('module', 'roles_permissions'), v_ip, v_user_agent, to_jsonb(OLD), NULL);
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
  v_action text;
  v_headers jsonb;
  v_user_agent text;
  v_ip text;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = COALESCE(NEW.role_id, OLD.role_id);
  v_headers := public.rbac_request_headers();
  v_user_agent := v_headers ->> 'user-agent';
  v_ip := COALESCE(v_headers ->> 'x-forwarded-for', v_headers ->> 'cf-connecting-ip', v_headers ->> 'x-real-ip');

  IF TG_OP = 'INSERT' THEN
    v_action := CASE WHEN NEW.accorde THEN 'permission_add' ELSE 'permission_remove' END;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, ip, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, v_code, v_action, jsonb_build_object('module', 'roles_permissions', 'permission', NEW.permission_code), v_ip, v_user_agent, NULL, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' AND OLD.accorde IS DISTINCT FROM NEW.accorde THEN
    v_action := CASE WHEN NEW.accorde THEN 'permission_add' ELSE 'permission_remove' END;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, ip, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, v_code, v_action, jsonb_build_object('module', 'roles_permissions', 'permission', NEW.permission_code), v_ip, v_user_agent, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, ip, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, OLD.role_id, v_code, 'permission_remove', jsonb_build_object('module', 'roles_permissions', 'permission', OLD.permission_code), v_ip, v_user_agent, to_jsonb(OLD), NULL);
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
  v_headers jsonb;
  v_user_agent text;
  v_ip text;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  v_target := COALESCE(NEW.user_id, OLD.user_id);
  SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = COALESCE(NEW.role_id, OLD.role_id);
  v_headers := public.rbac_request_headers();
  v_user_agent := v_headers ->> 'user-agent';
  v_ip := COALESCE(v_headers ->> 'x-forwarded-for', v_headers ->> 'cf-connecting-ip', v_headers ->> 'x-real-ip');

  INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, ip, user_agent, avant, apres)
  VALUES (
    auth.uid(), v_email, COALESCE(NEW.role_id, OLD.role_id), v_code,
    CASE WHEN TG_OP = 'INSERT' THEN 'role_assign' ELSE 'role_unassign' END,
    jsonb_build_object('module', 'roles_permissions', 'target_user_id', v_target),
    v_ip,
    v_user_agent,
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP = 'INSERT' THEN to_jsonb(NEW) ELSE NULL END
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;