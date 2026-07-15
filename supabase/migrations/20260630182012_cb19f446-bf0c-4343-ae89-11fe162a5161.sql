CREATE OR REPLACE FUNCTION public.guard_colis_historique_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL AND public.has_role(auth.uid(), 'super_admin'::app_role) THEN
    RETURN COALESCE(OLD, NEW);
  END IF;
  RAISE EXCEPTION 'Historique de suivi non modifiable';
END $function$;