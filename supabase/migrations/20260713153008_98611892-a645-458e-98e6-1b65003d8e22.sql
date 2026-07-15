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
    'assistante_comptable'::app_role,
    'secretariat'::app_role,
    'assistante'::app_role,
    'commercial'::app_role
  ])
$function$;