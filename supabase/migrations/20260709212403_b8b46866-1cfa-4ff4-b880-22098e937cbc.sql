CREATE OR REPLACE FUNCTION public.rbac_enforce_voir_before_action()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  perm_module text;
  perm_sous_module text;
  perm_action text;
  voir_code text;
BEGIN
  IF NEW.accorde IS DISTINCT FROM true THEN
    RETURN NEW;
  END IF;

  SELECT module, sous_module, action
  INTO perm_module, perm_sous_module, perm_action
  FROM public.rbac_permissions
  WHERE code = NEW.permission_code;

  IF perm_action IS NULL OR perm_action = 'voir' THEN
    RETURN NEW;
  END IF;

  SELECT code
  INTO voir_code
  FROM public.rbac_permissions
  WHERE sous_module = perm_sous_module
    AND action = 'voir'
  LIMIT 1;

  IF voir_code IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.rbac_role_permissions
    WHERE role_id = NEW.role_id
      AND permission_code = voir_code
      AND accorde = true
  ) THEN
    RAISE EXCEPTION 'Incohérence RBAC : l''action "voir" de l''écran % doit être accordée avant "%".',
      COALESCE(perm_sous_module, perm_module), perm_action USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac_cascade_voir_removal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  perm_sous_module text;
  perm_action text;
BEGIN
  SELECT sous_module, action
  INTO perm_sous_module, perm_action
  FROM public.rbac_permissions
  WHERE code = OLD.permission_code;

  IF perm_action = 'voir' THEN
    DELETE FROM public.rbac_role_permissions rp
    USING public.rbac_permissions p
    WHERE rp.role_id = OLD.role_id
      AND rp.permission_code = p.code
      AND p.sous_module = perm_sous_module
      AND p.action <> 'voir';
  END IF;

  RETURN OLD;
END;
$$;