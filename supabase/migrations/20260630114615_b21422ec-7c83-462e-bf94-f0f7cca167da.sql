
CREATE OR REPLACE FUNCTION public.trg_audit_generic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rid text;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD);
    v_rid := COALESCE(v_old->>'id', v_old->>(TG_TABLE_NAME||'_id'), '');
  ELSE
    v_new := to_jsonb(NEW);
    v_rid := COALESCE(v_new->>'id', v_new->>(TG_TABLE_NAME||'_id'), '');
    IF TG_OP = 'UPDATE' THEN v_old := to_jsonb(OLD); END IF;
  END IF;

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES(auth.uid(),
         COALESCE(auth.jwt()->>'email', auth.jwt()->'user_metadata'->>'nom_complet'),
         TG_OP, TG_TABLE_NAME, NULLIF(v_rid,''), v_old, v_new);

  RETURN COALESCE(NEW, OLD);
EXCEPTION WHEN OTHERS THEN
  RETURN COALESCE(NEW, OLD);
END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['depots','stocks_depots','inventaires','achats','incidents','specimens','commandes','factures','paiements','retours','transferts']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS audit_%I ON public.%I', t, t);
    EXECUTE format('CREATE TRIGGER audit_%I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.trg_audit_generic()', t, t);
  END LOOP;
END $$;
