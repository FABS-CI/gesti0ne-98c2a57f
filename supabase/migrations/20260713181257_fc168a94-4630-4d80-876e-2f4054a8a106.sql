
-- Élargit le trigger : tout rôle RBAC dont le code correspond à un app_role
-- (commercial, comptable, directeur_general, service_logistique, secretariat,
-- gestionnaire_stock, rh, etc.) est automatiquement miroir dans user_roles.
-- Le code "administrateur" reste alias de super_admin.
CREATE OR REPLACE FUNCTION public.sync_rbac_admin_to_legacy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  role_code text;
  mapped_role app_role;
BEGIN
  SELECT r.code INTO role_code
  FROM public.rbac_roles r
  WHERE r.role_id = NEW.role_id;

  IF role_code IS NULL THEN
    RETURN NEW;
  END IF;

  -- Alias explicite : "administrateur" == super_admin.
  IF role_code = 'administrateur' THEN
    mapped_role := 'super_admin'::app_role;
  ELSE
    -- Cast direct si le code correspond à un app_role connu ; sinon on ignore.
    BEGIN
      mapped_role := role_code::app_role;
    EXCEPTION WHEN invalid_text_representation THEN
      RETURN NEW;
    END;
  END IF;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.user_id, mapped_role)
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END;
$function$;

-- Rétroactif : synchronise tous les rôles RBAC existants dont le code
-- correspond à un app_role vers user_roles.
INSERT INTO public.user_roles (user_id, role)
SELECT DISTINCT ur.user_id,
       CASE WHEN r.code = 'administrateur' THEN 'super_admin'::app_role
            ELSE r.code::app_role END
FROM public.rbac_user_roles ur
JOIN public.rbac_roles r ON r.role_id = ur.role_id
WHERE COALESCE(r.actif, true)
  AND (
    r.code = 'administrateur'
    OR r.code IN (
      SELECT enumlabel FROM pg_enum e
      JOIN pg_type t ON t.oid = e.enumtypid
      WHERE t.typname = 'app_role'
    )
  )
ON CONFLICT (user_id, role) DO NOTHING;
