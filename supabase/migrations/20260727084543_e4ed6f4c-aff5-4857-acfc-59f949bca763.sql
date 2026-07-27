-- Sync rbac_user_roles (v1) -> rbac2_user_roles (v2) + user_roles (v0 enum)
CREATE OR REPLACE FUNCTION public.trg_rbac_user_roles_propagate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_code text;
BEGIN
  IF TG_OP IN ('INSERT','UPDATE') THEN
    SELECT r.code INTO v_code FROM public.rbac_roles r
      WHERE r.role_id = NEW.role_id OR r.id = NEW.rbac_role_id LIMIT 1;
    IF v_code IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM public.rbac2_roles WHERE code = v_code) THEN
        INSERT INTO public.rbac2_user_roles (user_id, role_code, granted_by)
        VALUES (NEW.user_id, v_code, NEW.assigned_by)
        ON CONFLICT DO NOTHING;
      END IF;
      IF EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
                 WHERE t.typname = 'app_role' AND e.enumlabel = v_code) THEN
        INSERT INTO public.user_roles (user_id, role)
        VALUES (NEW.user_id, v_code::app_role)
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- DELETE
  SELECT r.code INTO v_code FROM public.rbac_roles r
    WHERE r.role_id = OLD.role_id OR r.id = OLD.rbac_role_id LIMIT 1;
  IF v_code IS NOT NULL THEN
    DELETE FROM public.rbac2_user_roles WHERE user_id = OLD.user_id AND role_code = v_code;
    IF EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
               WHERE t.typname = 'app_role' AND e.enumlabel = v_code) THEN
      DELETE FROM public.user_roles WHERE user_id = OLD.user_id AND role = v_code::app_role;
    END IF;
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_rbac_user_roles_propagate ON public.rbac_user_roles;
CREATE TRIGGER trg_rbac_user_roles_propagate
AFTER INSERT OR UPDATE OR DELETE ON public.rbac_user_roles
FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_user_roles_propagate();

-- Backfill : aligne v2 et v0 sur v1
INSERT INTO public.rbac2_user_roles (user_id, role_code)
SELECT ur.user_id, r.code
FROM public.rbac_user_roles ur
JOIN public.rbac_roles r ON r.role_id = ur.role_id
JOIN public.rbac2_roles r2 ON r2.code = r.code
ON CONFLICT DO NOTHING;

INSERT INTO public.user_roles (user_id, role)
SELECT DISTINCT ur.user_id, r.code::app_role
FROM public.rbac_user_roles ur
JOIN public.rbac_roles r ON r.role_id = ur.role_id
WHERE EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
              WHERE t.typname = 'app_role' AND e.enumlabel = r.code)
ON CONFLICT DO NOTHING;