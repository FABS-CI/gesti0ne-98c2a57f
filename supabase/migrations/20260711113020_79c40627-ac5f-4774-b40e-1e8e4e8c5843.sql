-- 1. Ajouter les valeurs manquantes à l'enum app_role
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'responsable_logistique';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'rh';

-- 2. has_role : legacy OU RBAC v2
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role
  ) OR EXISTS(
    SELECT 1 FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = _user_id
      AND r.code = _role::text
      AND COALESCE(r.actif, true)
  )
$function$;

-- 3. has_any_role
CREATE OR REPLACE FUNCTION public.has_any_role(_user_id uuid, _roles app_role[])
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = ANY(_roles)
  ) OR EXISTS(
    SELECT 1 FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = _user_id
      AND r.code = ANY(SELECT unnest(_roles)::text)
      AND COALESCE(r.actif, true)
  )
$function$;

-- 4. is_staff : au moins un rôle assigné (legacy OU RBAC)
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id = _user_id)
      OR EXISTS(
        SELECT 1 FROM public.rbac_user_roles ur
        JOIN public.rbac_roles r ON r.role_id = ur.role_id
        WHERE ur.user_id = _user_id AND COALESCE(r.actif, true)
      )
$function$;

-- 5. has_operational_access
CREATE OR REPLACE FUNCTION public.has_operational_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT public.has_any_role(_user_id, ARRAY[
    'super_admin'::app_role,
    'directeur_general'::app_role,
    'service_logistique'::app_role,
    'responsable_magasinier'::app_role,
    'gestionnaire_stock'::app_role,
    'directeur_commercial'::app_role,
    'secretariat'::app_role
  ])
$function$;

-- 6. has_commercial_access
CREATE OR REPLACE FUNCTION public.has_commercial_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT public.has_any_role(_user_id, ARRAY[
    'super_admin'::app_role,
    'directeur_general'::app_role,
    'directeur_commercial'::app_role,
    'comptable'::app_role,
    'secretariat'::app_role,
    'assistante'::app_role
  ])
$function$;

-- 7. has_finance_access
CREATE OR REPLACE FUNCTION public.has_finance_access(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT public.has_any_role(_user_id, ARRAY[
    'super_admin'::app_role,
    'directeur_general'::app_role,
    'comptable'::app_role,
    'assistante_comptable'::app_role,
    'directeur_commercial'::app_role
  ])
$function$;