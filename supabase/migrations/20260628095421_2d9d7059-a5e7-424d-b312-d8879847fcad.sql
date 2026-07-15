CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  user_email text,
  action text NOT NULL,
  table_name text NOT NULL,
  record_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Audit lisible par direction"
ON public.audit_logs FOR SELECT
TO authenticated
USING (
  public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[])
);

CREATE POLICY "Audit insertion staff"
ON public.audit_logs FOR INSERT
TO authenticated
WITH CHECK (public.is_staff(auth.uid()));

CREATE OR REPLACE FUNCTION public.log_audit_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_rec_id text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT email INTO v_email FROM public.profiles WHERE id = v_uid;

  IF TG_OP = 'DELETE' THEN
    v_rec_id := OLD::text;
  ELSE
    v_rec_id := NEW::text;
  END IF;

  INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id)
  VALUES (
    v_uid,
    v_email,
    TG_OP,
    TG_TABLE_NAME,
    left(v_rec_id, 200)
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER audit_clients AFTER INSERT OR UPDATE OR DELETE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
CREATE TRIGGER audit_produits AFTER INSERT OR UPDATE OR DELETE ON public.produits FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
CREATE TRIGGER audit_commandes AFTER INSERT OR UPDATE OR DELETE ON public.commandes FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
CREATE TRIGGER audit_factures AFTER INSERT OR UPDATE OR DELETE ON public.factures FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
CREATE TRIGGER audit_paiements AFTER INSERT OR UPDATE OR DELETE ON public.paiements FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
CREATE TRIGGER audit_proformas AFTER INSERT OR UPDATE OR DELETE ON public.proformas FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();
CREATE TRIGGER audit_user_roles AFTER INSERT OR UPDATE OR DELETE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();