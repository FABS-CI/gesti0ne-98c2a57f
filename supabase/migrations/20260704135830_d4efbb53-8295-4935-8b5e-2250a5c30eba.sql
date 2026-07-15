
-- Resserrer l'INSERT policy
DROP POLICY IF EXISTS "audit_events insert authenticated" ON public.audit_events;
CREATE POLICY "audit_events insert authenticated"
  ON public.audit_events FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- Retirer l'EXECUTE PUBLIC par d\u00e9faut
REVOKE ALL ON FUNCTION public.log_audit_event(
  public.audit_action, text, text, text, text, text, text, text, text, integer, jsonb, inet, text
) FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION public.audit_row_change() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.jsonb_diff(jsonb, jsonb) FROM PUBLIC, anon;
