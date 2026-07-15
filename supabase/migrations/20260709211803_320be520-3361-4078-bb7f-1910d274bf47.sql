-- Rendre la vérification "voir avant les autres actions" différée
-- pour qu'elle s'évalue à la fin de la transaction (batch inserts OK).

DROP TRIGGER IF EXISTS trg_rbac_enforce_voir ON public.rbac_role_permissions;

CREATE OR REPLACE FUNCTION public.rbac_enforce_voir_before_action()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  perm_module text;
  perm_action text;
  voir_code text;
BEGIN
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
  RETURN NEW;
END;
$$;

-- Constraint trigger : DEFERRABLE INITIALLY DEFERRED -> exécuté au COMMIT,
-- donc toutes les lignes du batch (dont "voir") sont déjà visibles.
CREATE CONSTRAINT TRIGGER trg_rbac_enforce_voir
  AFTER INSERT OR UPDATE ON public.rbac_role_permissions
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.rbac_enforce_voir_before_action();
