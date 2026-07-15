
-- Archive table (même schéma que audit_events)
CREATE TABLE IF NOT EXISTS public.audit_events_archive (LIKE public.audit_events INCLUDING ALL);

GRANT SELECT ON public.audit_events_archive TO authenticated;
GRANT ALL ON public.audit_events_archive TO service_role;

ALTER TABLE public.audit_events_archive ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_archive_read_privileged" ON public.audit_events_archive;
CREATE POLICY "audit_archive_read_privileged"
ON public.audit_events_archive FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'super_admin')
  OR public.has_role(auth.uid(), 'directeur_general')
  OR public.has_role(auth.uid(), 'comptable')
);

CREATE INDEX IF NOT EXISTS idx_audit_events_occurred_at
  ON public.audit_events (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_archive_occurred_at
  ON public.audit_events_archive (occurred_at DESC);

-- Fonction d'archivage : déplace les événements > p_months mois
CREATE OR REPLACE FUNCTION public.audit_events_archive_old(p_months integer DEFAULT 12)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_moved integer := 0;
BEGIN
  IF NOT (public.has_role(auth.uid(), 'super_admin')
          OR public.has_role(auth.uid(), 'directeur_general')) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  WITH moved AS (
    DELETE FROM public.audit_events
    WHERE occurred_at < now() - (p_months || ' months')::interval
    RETURNING *
  )
  INSERT INTO public.audit_events_archive SELECT * FROM moved;

  GET DIAGNOSTICS v_moved = ROW_COUNT;
  RETURN v_moved;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_events_archive_old(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_events_archive_old(integer) TO authenticated;

-- Vue unifiée (actifs + archives)
CREATE OR REPLACE VIEW public.audit_events_all AS
  SELECT *, false AS archived FROM public.audit_events
  UNION ALL
  SELECT *, true  AS archived FROM public.audit_events_archive;

GRANT SELECT ON public.audit_events_all TO authenticated;
