CREATE OR REPLACE FUNCTION public.trg_rbac2_user_roles_propagate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_role app_role;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_code := OLD.role_code;
  ELSE
    v_code := NEW.role_code;
  END IF;

  -- Ignore les codes v2 qui n'existent pas dans l'enum historique app_role
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'app_role' AND e.enumlabel = v_code
  ) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_role := v_code::app_role;

  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.user_roles WHERE user_id = OLD.user_id AND role = v_role;
  ELSE
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.user_id, v_role)
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_rbac2_user_roles_propagate ON public.rbac2_user_roles;
CREATE TRIGGER trg_rbac2_user_roles_propagate
AFTER INSERT OR UPDATE OR DELETE ON public.rbac2_user_roles
FOR EACH ROW EXECUTE FUNCTION public.trg_rbac2_user_roles_propagate();

-- Backfill v2 -> v0
INSERT INTO public.user_roles (user_id, role)
SELECT ur.user_id, ur.role_code::app_role
FROM public.rbac2_user_roles ur
WHERE EXISTS (
  SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
  WHERE t.typname = 'app_role' AND e.enumlabel = ur.role_code
)
ON CONFLICT DO NOTHING;