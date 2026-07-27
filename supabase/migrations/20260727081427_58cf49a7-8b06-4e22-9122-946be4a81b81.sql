CREATE OR REPLACE FUNCTION public.approbation_escalader_sla()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN
    SELECT id, reference, entity_type, module, demandeur_nom, sla_deadline, historique, metadata
    FROM public.workflow_approvals
    WHERE statut = 'en_attente'
      AND sla_deadline IS NOT NULL
      AND sla_deadline < now()
      AND COALESCE((metadata->>'escalade')::boolean, false) = false
    ORDER BY sla_deadline ASC
    LIMIT 200
  LOOP
    UPDATE public.workflow_approvals
    SET niveau_urgence = 'critique',
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'escalade', true,
          'escalade_at', now()
        ),
        historique = COALESCE(historique, '[]'::jsonb) || jsonb_build_object(
          'action', 'escalade',
          'at', now(),
          'motif', 'SLA dépassé — escalade automatique vers la Direction'
        ),
        updated_at = now()
    WHERE id = r.id;

    PERFORM public._notifier_role(
      r.id::text,
      COALESCE(r.reference, r.entity_type),
      'approbation',
      '/approbations',
      'Demande ' || COALESCE(r.reference, r.entity_type) || ' en attente depuis le ' ||
        to_char(r.sla_deadline, 'DD/MM/YYYY HH24:MI') || ' — délai dépassé.',
      COALESCE(r.module, 'approbations'),
      'directeur_general',
      'Approbation escaladée (SLA dépassé)'
    );

    PERFORM public._notifier_role(
      r.id::text,
      COALESCE(r.reference, r.entity_type),
      'approbation',
      '/approbations',
      'Demande ' || COALESCE(r.reference, r.entity_type) || ' en attente depuis le ' ||
        to_char(r.sla_deadline, 'DD/MM/YYYY HH24:MI') || ' — délai dépassé.',
      COALESCE(r.module, 'approbations'),
      'super_admin',
      'Approbation escaladée (SLA dépassé)'
    );

    n := n + 1;
  END LOOP;

  RETURN jsonb_build_object('escalades', n, 'at', now());
END;
$$;

REVOKE ALL ON FUNCTION public.approbation_escalader_sla() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approbation_escalader_sla() TO authenticated, service_role;