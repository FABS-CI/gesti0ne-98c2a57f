-- Défense en profondeur : verrouiller UPDATE/DELETE sur audit_logs et DELETE sur colisage_responsables
-- via des policies RESTRICTIVE (combinées en AND, jamais en OR avec d'autres policies).

-- ── audit_logs : immuables ──────────────────────────────────────────────
DROP POLICY IF EXISTS "Audit logs are immutable (no update)" ON public.audit_logs;
CREATE POLICY "Audit logs are immutable (no update)"
  ON public.audit_logs
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS "Audit logs are immutable (no delete)" ON public.audit_logs;
CREATE POLICY "Audit logs are immutable (no delete)"
  ON public.audit_logs
  AS RESTRICTIVE
  FOR DELETE
  TO authenticated
  USING (false);

-- ── colisage_responsables : pas de suppression ──────────────────────────
DROP POLICY IF EXISTS "colisage_resp no delete" ON public.colisage_responsables;
CREATE POLICY "colisage_resp no delete"
  ON public.colisage_responsables
  AS RESTRICTIVE
  FOR DELETE
  TO authenticated
  USING (false);