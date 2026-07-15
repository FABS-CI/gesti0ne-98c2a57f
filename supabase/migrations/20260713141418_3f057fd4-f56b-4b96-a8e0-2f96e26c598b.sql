
-- Ajout du rôle commercial dans user_roles pour claverie
INSERT INTO public.user_roles (user_id, role)
VALUES ('de692f12-2be3-4d44-8284-fd093bf45d47', 'commercial'::public.app_role)
ON CONFLICT DO NOTHING;

-- Étendre l'accès commercial (clients, commandes) au rôle 'commercial'
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
    'assistante'::app_role,
    'commercial'::app_role
  ])
$function$;

-- Étendre l'accès opérationnel (bons de livraison) au rôle 'commercial' (lecture)
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
    'secretariat'::app_role,
    'commercial'::app_role
  ])
$function$;
