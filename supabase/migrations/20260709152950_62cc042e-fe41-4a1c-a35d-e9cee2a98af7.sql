
CREATE OR REPLACE FUNCTION public.enforce_document_type_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sensitive_types text[] := ARRAY['finance','comptabilite','paie','rh','contrat','bulletin','fiscal'];
  old_sensitive boolean := OLD.type_document = ANY(sensitive_types);
  new_sensitive boolean := NEW.type_document = ANY(sensitive_types);
  is_privileged boolean := has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role, 'comptable'::app_role]);
BEGIN
  IF OLD.type_document IS DISTINCT FROM NEW.type_document
     AND (old_sensitive OR new_sensitive)
     AND NOT is_privileged THEN
    RAISE EXCEPTION 'Modification du type_document sensible interdite pour ce rôle';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_document_type_transition ON public.documents;
CREATE TRIGGER trg_enforce_document_type_transition
BEFORE UPDATE ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.enforce_document_type_transition();
