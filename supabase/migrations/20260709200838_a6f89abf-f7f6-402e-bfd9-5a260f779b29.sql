
CREATE OR REPLACE FUNCTION public.trg_rbac_audit_rp()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text; v_code text;
  v_ua text; v_headers jsonb;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  BEGIN
    v_headers := current_setting('request.headers', true)::jsonb;
    v_ua := v_headers ->> 'user-agent';
  EXCEPTION WHEN OTHERS THEN v_ua := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = NEW.role_id;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, v_code,
      CASE WHEN NEW.accorde THEN 'perm_add' ELSE 'perm_remove' END,
      jsonb_build_object('permission', NEW.permission_code, 'accorde', NEW.accorde),
      v_ua,
      NULL,
      jsonb_build_object('permission', NEW.permission_code, 'accorde', NEW.accorde));
  ELSIF TG_OP = 'UPDATE' AND OLD.accorde IS DISTINCT FROM NEW.accorde THEN
    SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = NEW.role_id;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, v_code,
      CASE WHEN NEW.accorde THEN 'perm_add' ELSE 'perm_remove' END,
      jsonb_build_object('permission', NEW.permission_code, 'accorde', NEW.accorde),
      v_ua,
      jsonb_build_object('permission', OLD.permission_code, 'accorde', OLD.accorde),
      jsonb_build_object('permission', NEW.permission_code, 'accorde', NEW.accorde));
  ELSIF TG_OP = 'DELETE' THEN
    SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = OLD.role_id;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, OLD.role_id, v_code, 'perm_remove',
      jsonb_build_object('permission', OLD.permission_code),
      v_ua,
      jsonb_build_object('permission', OLD.permission_code, 'accorde', OLD.accorde),
      NULL);
  END IF;
  RETURN COALESCE(NEW, OLD);
END; $function$;

CREATE OR REPLACE FUNCTION public.trg_rbac_audit_ur()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_email text; v_code text; v_target uuid;
  v_ua text; v_headers jsonb;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  BEGIN
    v_headers := current_setting('request.headers', true)::jsonb;
    v_ua := v_headers ->> 'user-agent';
  EXCEPTION WHEN OTHERS THEN v_ua := NULL;
  END;
  v_target := COALESCE(NEW.user_id, OLD.user_id);
  SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = COALESCE(NEW.role_id, OLD.role_id);
  INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, user_agent, avant, apres)
  VALUES (auth.uid(), v_email, COALESCE(NEW.role_id, OLD.role_id), v_code,
    CASE WHEN TG_OP='INSERT' THEN 'assign' ELSE 'unassign' END,
    jsonb_build_object('target_user_id', v_target),
    v_ua,
    CASE WHEN TG_OP='DELETE' THEN jsonb_build_object('target_user_id', v_target, 'role_id', OLD.role_id) ELSE NULL END,
    CASE WHEN TG_OP='INSERT' THEN jsonb_build_object('target_user_id', v_target, 'role_id', NEW.role_id) ELSE NULL END);
  RETURN COALESCE(NEW, OLD);
END; $function$;
