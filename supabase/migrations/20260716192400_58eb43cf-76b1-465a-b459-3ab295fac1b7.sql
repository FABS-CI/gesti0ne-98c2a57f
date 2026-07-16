CREATE OR REPLACE FUNCTION public.trg_rbac_user_roles_sync_legacy()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  -- role_id référence rbac_roles.role_id ; rbac_role_id référence rbac_roles.id.
  -- On résout la correspondance via rbac_roles, plutôt que de recopier bêtement
  -- une valeur d'une colonne dans l'autre (ce qui violait la FK).
  IF NEW.rbac_role_id IS NULL AND NEW.role_id IS NOT NULL THEN
    SELECT r.id INTO NEW.rbac_role_id
    FROM public.rbac_roles r
    WHERE r.role_id = NEW.role_id;
  END IF;
  IF NEW.role_id IS NULL AND NEW.rbac_role_id IS NOT NULL THEN
    SELECT r.role_id INTO NEW.role_id
    FROM public.rbac_roles r
    WHERE r.id = NEW.rbac_role_id;
  END IF;
  RETURN NEW;
END;
$function$;