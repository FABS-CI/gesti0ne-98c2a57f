
-- 1. Enum des actions auditées
DO $$ BEGIN
  CREATE TYPE public.audit_action AS ENUM (
    'INSERT','UPDATE','DELETE',
    'LOGIN','LOGIN_FAILED','LOGOUT',
    'EXPORT','IMPORT','PRINT','DOWNLOAD','UPLOAD',
    'VALIDATION','APPROBATION','ANNULATION','CONSULTATION'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Table audit_events
CREATE TABLE public.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigserial NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  user_id uuid,
  user_email text,
  action public.audit_action NOT NULL,
  module text,
  table_name text,
  record_id text,
  record_ref text,
  old_values jsonb,
  new_values jsonb,
  changes jsonb,
  ip_address inet,
  user_agent text,
  request_id text,
  session_id text,
  url text,
  http_method text,
  status text NOT NULL DEFAULT 'success',
  error_message text,
  duration_ms integer,
  metadata jsonb
);

-- 3. GRANTs (INSERT ouvert pour permettre au trigger d'\u00e9crire; SELECT filtr\u00e9 par RLS)
GRANT SELECT, INSERT ON public.audit_events TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.audit_events_seq_seq TO authenticated;
GRANT ALL ON public.audit_events TO service_role;
GRANT ALL ON SEQUENCE public.audit_events_seq_seq TO service_role;

-- 4. RLS : lecture super_admin / DG uniquement ; aucune UPDATE/DELETE possible
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_events select super admin"
  ON public.audit_events FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role]));

CREATE POLICY "audit_events insert authenticated"
  ON public.audit_events FOR INSERT TO authenticated
  WITH CHECK (true);

-- 5. Index de recherche
CREATE INDEX audit_events_occurred_at_idx ON public.audit_events (occurred_at DESC);
CREATE INDEX audit_events_user_time_idx   ON public.audit_events (user_id, occurred_at DESC);
CREATE INDEX audit_events_table_rec_idx   ON public.audit_events (table_name, record_id);
CREATE INDEX audit_events_action_idx      ON public.audit_events (action);

-- 6. Diff JSONB champ par champ
CREATE OR REPLACE FUNCTION public.jsonb_diff(old jsonb, new jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT COALESCE(jsonb_object_agg(k, jsonb_build_object('old', old->k, 'new', new->k)), '{}'::jsonb)
  FROM (
    SELECT jsonb_object_keys(COALESCE(old, '{}'::jsonb) || COALESCE(new, '{}'::jsonb)) AS k
  ) s
  WHERE (old->k) IS DISTINCT FROM (new->k);
$$;

-- 7. Trigger g\u00e9n\u00e9rique de capture CRUD
CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_rec_id text;
  v_email text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_new := to_jsonb(NEW);
    v_rec_id := (v_new->>'id');
  ELSIF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_rec_id := (v_new->>'id');
  ELSIF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD);
    v_rec_id := (v_old->>'id');
  END IF;

  BEGIN
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_email := NULL;
  END;

  INSERT INTO public.audit_events(
    user_id, user_email, action, table_name, record_id,
    old_values, new_values, changes
  ) VALUES (
    auth.uid(),
    v_email,
    TG_OP::public.audit_action,
    TG_TABLE_NAME,
    v_rec_id,
    v_old,
    v_new,
    CASE WHEN TG_OP = 'UPDATE' THEN public.jsonb_diff(v_old, v_new) ELSE NULL END
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- 8. Attacher les triggers aux tables cl\u00e9s
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'clients','commandes','factures','paiements','retours',
    'produits','stock_mouvements','inventaires','transferts',
    'employes','contrats','bulletins_paie','absences','conges'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%1$s ON public.%1$I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit_%1$s AFTER INSERT OR UPDATE OR DELETE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()',
      t
    );
  END LOOP;
END $$;

-- 9. RPC pour \u00e9v\u00e9nements front (LOGIN / EXPORT / PRINT / CONSULTATION\u2026)
CREATE OR REPLACE FUNCTION public.log_audit_event(
  p_action public.audit_action,
  p_module text DEFAULT NULL,
  p_table_name text DEFAULT NULL,
  p_record_id text DEFAULT NULL,
  p_record_ref text DEFAULT NULL,
  p_url text DEFAULT NULL,
  p_http_method text DEFAULT NULL,
  p_status text DEFAULT 'success',
  p_error_message text DEFAULT NULL,
  p_duration_ms integer DEFAULT NULL,
  p_metadata jsonb DEFAULT NULL,
  p_ip inet DEFAULT NULL,
  p_user_agent text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_id uuid;
BEGIN
  BEGIN
    SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_email := NULL;
  END;

  INSERT INTO public.audit_events(
    user_id, user_email, action, module, table_name, record_id, record_ref,
    url, http_method, status, error_message, duration_ms, metadata, ip_address, user_agent
  ) VALUES (
    auth.uid(), v_email, p_action, p_module, p_table_name, p_record_id, p_record_ref,
    p_url, p_http_method, p_status, p_error_message, p_duration_ms, p_metadata, p_ip, p_user_agent
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_audit_event(
  public.audit_action, text, text, text, text, text, text, text, text, integer, jsonb, inet, text
) TO authenticated;
