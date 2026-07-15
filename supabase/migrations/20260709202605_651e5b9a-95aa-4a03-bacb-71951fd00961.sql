-- 1. Ré-attache les triggers d'audit sur rbac_role_permissions et rbac_user_roles
DROP TRIGGER IF EXISTS trg_rbac_audit_rp ON public.rbac_role_permissions;
CREATE TRIGGER trg_rbac_audit_rp
AFTER INSERT OR UPDATE OR DELETE ON public.rbac_role_permissions
FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_rp();

DROP TRIGGER IF EXISTS trg_rbac_audit_ur ON public.rbac_user_roles;
CREATE TRIGGER trg_rbac_audit_ur
AFTER INSERT OR DELETE ON public.rbac_user_roles
FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_ur();

-- 2. Ré-attache les triggers de cohérence
DROP TRIGGER IF EXISTS trg_rbac_enforce_voir ON public.rbac_role_permissions;
CREATE TRIGGER trg_rbac_enforce_voir
BEFORE INSERT OR UPDATE ON public.rbac_role_permissions
FOR EACH ROW EXECUTE FUNCTION public.rbac_enforce_voir_before_action();

DROP TRIGGER IF EXISTS trg_rbac_cascade_voir ON public.rbac_role_permissions;
CREATE TRIGGER trg_rbac_cascade_voir
AFTER DELETE ON public.rbac_role_permissions
FOR EACH ROW EXECUTE FUNCTION public.rbac_cascade_voir_removal();

-- 3. Nouvelle fonction et trigger pour auditer les rôles eux-mêmes
CREATE OR REPLACE FUNCTION public.trg_rbac_audit_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text;
  v_ua text;
  v_headers jsonb;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  BEGIN
    v_headers := current_setting('request.headers', true)::jsonb;
    v_ua := v_headers ->> 'user-agent';
  EXCEPTION WHEN OTHERS THEN v_ua := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, NEW.code, 'role_create',
      jsonb_build_object('libelle', NEW.libelle),
      v_ua, NULL,
      jsonb_build_object('code', NEW.code, 'libelle', NEW.libelle, 'description', NEW.description, 'hierite_de', NEW.hierite_de, 'actif', NEW.actif));
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, NEW.role_id, NEW.code, 'role_update',
      jsonb_build_object('libelle', NEW.libelle),
      v_ua,
      jsonb_build_object('code', OLD.code, 'libelle', OLD.libelle, 'description', OLD.description, 'hierite_de', OLD.hierite_de, 'actif', OLD.actif),
      jsonb_build_object('code', NEW.code, 'libelle', NEW.libelle, 'description', NEW.description, 'hierite_de', NEW.hierite_de, 'actif', NEW.actif));
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details, user_agent, avant, apres)
    VALUES (auth.uid(), v_email, OLD.role_id, OLD.code, 'role_delete',
      jsonb_build_object('libelle', OLD.libelle),
      v_ua,
      jsonb_build_object('code', OLD.code, 'libelle', OLD.libelle, 'description', OLD.description, 'hierite_de', OLD.hierite_de, 'actif', OLD.actif),
      NULL);
  END IF;
  RETURN COALESCE(NEW, OLD);
END; $$;

DROP TRIGGER IF EXISTS trg_rbac_audit_role ON public.rbac_roles;
CREATE TRIGGER trg_rbac_audit_role
AFTER INSERT OR UPDATE OR DELETE ON public.rbac_roles
FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_role();