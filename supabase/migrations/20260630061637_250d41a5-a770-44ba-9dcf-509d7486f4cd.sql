CREATE OR REPLACE FUNCTION public.guard_commande_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Le super_admin peut toujours supprimer une commande
  IF public.has_role(auth.uid(), 'super_admin') THEN
    RETURN OLD;
  END IF;
  IF OLD.statut IN ('validee','facturee','livree') THEN
    RAISE EXCEPTION 'Suppression interdite: commande % au statut %', OLD.reference, OLD.statut
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END;
$$;