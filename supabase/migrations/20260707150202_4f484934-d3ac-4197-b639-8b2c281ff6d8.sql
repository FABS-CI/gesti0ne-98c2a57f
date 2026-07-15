
-- Generic audit trigger function for documents & colis_statut_historique
CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_action audit_action;
  v_record_id text;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_action := 'create'::audit_action;
    v_old := NULL;
    v_new := to_jsonb(NEW);
    v_record_id := COALESCE((v_new->>'id'), (v_new->>'document_id'), (v_new->>'historique_id'));
  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'update'::audit_action;
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_record_id := COALESCE((v_new->>'id'), (v_new->>'document_id'), (v_new->>'historique_id'));
  ELSE
    v_action := 'delete'::audit_action;
    v_old := to_jsonb(OLD);
    v_new := NULL;
    v_record_id := COALESCE((v_old->>'id'), (v_old->>'document_id'), (v_old->>'historique_id'));
  END IF;

  INSERT INTO public.audit_events (
    user_id, action, module, table_name, record_id, old_values, new_values, status
  ) VALUES (
    auth.uid(), v_action, 'security', TG_TABLE_NAME, v_record_id, v_old, v_new, 'success'
  );

  RETURN COALESCE(NEW, OLD);
EXCEPTION WHEN OTHERS THEN
  -- Never break the underlying operation because of audit failure
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_documents ON public.documents;
CREATE TRIGGER trg_audit_documents
AFTER INSERT OR UPDATE OR DELETE ON public.documents
FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_colis_statut_historique ON public.colis_statut_historique;
CREATE TRIGGER trg_audit_colis_statut_historique
AFTER INSERT OR UPDATE OR DELETE ON public.colis_statut_historique
FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();
