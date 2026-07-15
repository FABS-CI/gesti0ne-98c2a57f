DROP TRIGGER IF EXISTS trg_rbac_enforce_voir ON public.rbac_role_permissions;
DROP TRIGGER IF EXISTS trg_rbac_cascade_voir ON public.rbac_role_permissions;

DROP FUNCTION IF EXISTS public.rbac_enforce_voir_before_action();
DROP FUNCTION IF EXISTS public.rbac_cascade_voir_removal();