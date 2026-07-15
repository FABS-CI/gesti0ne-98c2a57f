
-- 1) Fonctions helpers
CREATE OR REPLACE FUNCTION public.user_permissions(_user_id uuid)
RETURNS SETOF text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT DISTINCT rp.permission_code
  FROM public.rbac_user_roles ur
  JOIN public.rbac_role_permissions rp ON rp.role_id = ur.role_id
  JOIN public.rbac_roles r ON r.role_id = ur.role_id
  WHERE ur.user_id = _user_id AND r.actif AND rp.accorde = true;
$$;

CREATE OR REPLACE FUNCTION public.has_permission(_user_id uuid, _perm text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT public.has_permission_v2(_user_id, _perm);
$$;

CREATE OR REPLACE FUNCTION public.has_module(_user_id uuid, _module text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_permissions(_user_id) p
    JOIN public.rbac_permissions perm ON perm.code = p
    WHERE perm.module = _module
  );
$$;

REVOKE ALL ON FUNCTION public.user_permissions(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_permission(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_module(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_permissions(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_permission(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_module(uuid, text) TO authenticated, service_role;

-- 2) Enrichissement audit
ALTER TABLE public.rbac_audit_log
  ADD COLUMN IF NOT EXISTS user_agent text,
  ADD COLUMN IF NOT EXISTS avant jsonb,
  ADD COLUMN IF NOT EXISTS apres jsonb;

-- 3) Cohérence permissions : voir requis pour les autres actions
CREATE OR REPLACE FUNCTION public.rbac_enforce_voir_before_action()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  perm_module text;
  perm_action text;
  voir_code text;
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.accorde IS DISTINCT FROM true THEN
      RETURN NEW;
    END IF;
    SELECT module, action INTO perm_module, perm_action
      FROM public.rbac_permissions WHERE code = NEW.permission_code;
    IF perm_action IS NULL OR perm_action = 'voir' THEN
      RETURN NEW;
    END IF;
    SELECT code INTO voir_code
      FROM public.rbac_permissions
      WHERE module = perm_module AND action = 'voir' LIMIT 1;
    IF voir_code IS NULL THEN RETURN NEW; END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.rbac_role_permissions
      WHERE role_id = NEW.role_id
        AND permission_code = voir_code
        AND accorde = true
    ) THEN
      RAISE EXCEPTION 'Incohérence RBAC : l''action "voir" du module % doit être accordée avant "%".',
        perm_module, perm_action USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rbac_enforce_voir ON public.rbac_role_permissions;
CREATE TRIGGER trg_rbac_enforce_voir
  BEFORE INSERT OR UPDATE ON public.rbac_role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.rbac_enforce_voir_before_action();

-- Cascade : retrait de "voir" retire les permissions dépendantes du même module pour le même rôle
CREATE OR REPLACE FUNCTION public.rbac_cascade_voir_removal()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  perm_module text;
  perm_action text;
BEGIN
  SELECT module, action INTO perm_module, perm_action
    FROM public.rbac_permissions WHERE code = OLD.permission_code;
  IF perm_action = 'voir' THEN
    DELETE FROM public.rbac_role_permissions rp
    USING public.rbac_permissions p
    WHERE rp.role_id = OLD.role_id
      AND rp.permission_code = p.code
      AND p.module = perm_module
      AND p.action <> 'voir';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_rbac_cascade_voir ON public.rbac_role_permissions;
CREATE TRIGGER trg_rbac_cascade_voir
  AFTER DELETE ON public.rbac_role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.rbac_cascade_voir_removal();
