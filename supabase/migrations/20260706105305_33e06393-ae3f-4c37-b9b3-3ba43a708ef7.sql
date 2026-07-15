
CREATE OR REPLACE FUNCTION public.notifier_points_expirants()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nb_clients INTEGER;
  v_total_points BIGINT;
BEGIN
  WITH agg AS (
    SELECT client_id, SUM(points) AS pts
    FROM public.client_fidelite_mouvements
    WHERE type = 'gain'
      AND date_expiration IS NOT NULL
      AND date_expiration > now()
      AND date_expiration <= now() + INTERVAL '30 days'
    GROUP BY client_id
    HAVING SUM(points) > 0
  )
  SELECT COUNT(*)::int, COALESCE(SUM(pts),0)::bigint
    INTO v_nb_clients, v_total_points
  FROM agg;

  IF v_nb_clients = 0 THEN
    RETURN 0;
  END IF;

  INSERT INTO public.notifications
    (titre, message, module, type_notification, priorite, role_cible, lien)
  VALUES
    (
      'Points de fidélité expirant sous 30 jours',
      v_nb_clients || ' client(s) ont un total de ' || v_total_points ||
        ' points expirant dans les 30 prochains jours (≈ ' ||
        to_char(v_total_points * 10, 'FM999G999G999') || ' F CFA).',
      'fidelite',
      'alerte',
      'haute',
      'directeur_general',
      '/admin/fidelite'
    );

  INSERT INTO public.notifications
    (titre, message, module, type_notification, priorite, role_cible, lien)
  VALUES
    (
      'Points de fidélité expirant sous 30 jours',
      v_nb_clients || ' clients concernés — ' || v_total_points || ' points au total.',
      'fidelite',
      'alerte',
      'haute',
      'super_admin',
      '/admin/fidelite'
    );

  RETURN v_nb_clients;
END;
$$;

-- Planifier tous les lundis à 07:00 UTC
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('notifier-points-expirants-hebdo')
      WHERE EXISTS (
        SELECT 1 FROM cron.job WHERE jobname = 'notifier-points-expirants-hebdo'
      );
    PERFORM cron.schedule(
      'notifier-points-expirants-hebdo',
      '0 7 * * 1',
      $cron$ SELECT public.notifier_points_expirants(); $cron$
    );
  END IF;
END $$;
