
-- 1) Étend has_any_role pour traiter le code RBAC "administrateur" comme "super_admin".
CREATE OR REPLACE FUNCTION public.has_any_role(_user_id uuid, _roles app_role[])
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = ANY(_roles)
  )
  OR EXISTS(
    SELECT 1
    FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = _user_id
      AND COALESCE(r.actif, true)
      AND (
        r.code = ANY(SELECT unnest(_roles)::text)
        -- Alias : le rôle "administrateur" équivaut à "super_admin".
        OR (r.code = 'administrateur' AND 'super_admin'::app_role = ANY(_roles))
      )
  );
$function$;

-- 2) Trigger : lorsqu'un utilisateur reçoit le rôle RBAC "administrateur" ou
--    "super_admin", on l'inscrit aussi dans user_roles comme super_admin pour
--    que toutes les fonctions historiques (has_commercial_access,
--    has_finance_access, has_operational_access, is_staff, etc.) le
--    reconnaissent automatiquement.
CREATE OR REPLACE FUNCTION public.sync_rbac_admin_to_legacy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  role_code text;
BEGIN
  SELECT r.code INTO role_code
  FROM public.rbac_roles r
  WHERE r.role_id = NEW.role_id;

  IF role_code IN ('administrateur', 'super_admin') THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.user_id, 'super_admin'::app_role)
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_rbac_admin_to_legacy ON public.rbac_user_roles;
CREATE TRIGGER trg_sync_rbac_admin_to_legacy
AFTER INSERT ON public.rbac_user_roles
FOR EACH ROW EXECUTE FUNCTION public.sync_rbac_admin_to_legacy();

-- 3) Rétroactif : tous les utilisateurs déjà porteurs du rôle RBAC
--    "administrateur" ou "super_admin" sont ajoutés dans user_roles.
INSERT INTO public.user_roles (user_id, role)
SELECT ur.user_id, 'super_admin'::app_role
FROM public.rbac_user_roles ur
JOIN public.rbac_roles r ON r.role_id = ur.role_id
WHERE r.code IN ('administrateur', 'super_admin')
  AND COALESCE(r.actif, true)
ON CONFLICT (user_id, role) DO NOTHING;
