CREATE OR REPLACE FUNCTION public.prevent_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Journal d''audit inaltérable : % interdit sur %', TG_OP, TG_TABLE_NAME
    USING ERRCODE = '42501';
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'audit_logs',
    'rbac2_audit',
    'rbac_audit_log',
    'paiement_annulations_audit',
    'couts_logistiques_audit',
    'exercice_cloture_journal'
  ] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_append_only ON public.%I', t, t);
      EXECUTE format(
        'CREATE TRIGGER trg_%s_append_only BEFORE UPDATE OR DELETE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_audit_mutation()',
        t, t
      );
      EXECUTE format('REVOKE UPDATE, DELETE, TRUNCATE ON public.%I FROM authenticated, anon', t);
    END IF;
  END LOOP;
END;
$$;