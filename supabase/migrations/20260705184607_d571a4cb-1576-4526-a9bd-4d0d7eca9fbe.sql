
-- Table de debug pour tracer chaque exécution de recalc_tournee_from_colis
CREATE TABLE IF NOT EXISTS public.trigger_execution_log (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  executed_at  timestamptz NOT NULL DEFAULT now(),
  trigger_name text NOT NULL,
  target_date  date,
  nb_colis     int,
  nb_cartons   int,
  nb_clients   int,
  chauffeur    text,
  responsable  text,
  immat        text,
  affected_rows int,
  message      text
);

CREATE INDEX IF NOT EXISTS idx_trigger_exec_log_executed_at
  ON public.trigger_execution_log (executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_trigger_exec_log_target_date
  ON public.trigger_execution_log (target_date);

GRANT SELECT ON public.trigger_execution_log TO authenticated;
GRANT ALL    ON public.trigger_execution_log TO service_role;

ALTER TABLE public.trigger_execution_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff read trigger_execution_log" ON public.trigger_execution_log;
CREATE POLICY "staff read trigger_execution_log"
  ON public.trigger_execution_log FOR SELECT
  TO authenticated
  USING (public.is_staff(auth.uid()));

-- Purge automatique : ne garder que les 30 derniers jours
CREATE OR REPLACE FUNCTION public.trigger_execution_log_purge()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $$
  DELETE FROM public.trigger_execution_log
   WHERE executed_at < now() - interval '30 days';
$$;

-- Recalcul instrumenté : insère une ligne dans trigger_execution_log
CREATE OR REPLACE FUNCTION public.recalc_tournee_from_colis(_date date)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_nb_colis int; v_nb_cartons int; v_nb_clients int;
  v_chauffeur text; v_responsable text; v_immat text;
  v_vehicule_id uuid; v_updated int := 0;
BEGIN
  IF _date IS NULL THEN
    INSERT INTO public.trigger_execution_log(trigger_name, target_date, affected_rows, message)
      VALUES ('recalc_tournee_from_colis', NULL, 0, 'date NULL, skip');
    RETURN 0;
  END IF;
  SELECT count(*)::int, COALESCE(sum(nb_cartons),0)::int INTO v_nb_colis, v_nb_cartons
    FROM public.colis WHERE date_colisage::date = _date;
  SELECT count(DISTINCT c.client_id)::int INTO v_nb_clients
    FROM public.colis co JOIN public.commandes c ON c.commande_id = co.commande_id
    WHERE co.date_colisage::date = _date;
  SELECT livreur_nom INTO v_chauffeur FROM public.colis
    WHERE date_colisage::date = _date AND coalesce(btrim(livreur_nom),'') <> ''
    GROUP BY livreur_nom ORDER BY count(*) DESC LIMIT 1;
  SELECT responsable_nom INTO v_responsable FROM public.colis
    WHERE date_colisage::date = _date AND coalesce(btrim(responsable_nom),'') <> ''
    GROUP BY responsable_nom ORDER BY count(*) DESC LIMIT 1;
  SELECT vehicule INTO v_immat FROM public.colis
    WHERE date_colisage::date = _date AND coalesce(btrim(vehicule),'') <> ''
    GROUP BY vehicule ORDER BY count(*) DESC LIMIT 1;
  IF v_immat IS NOT NULL THEN
    SELECT vehicule_id INTO v_vehicule_id FROM public.vehicules
      WHERE immatriculation ILIKE v_immat LIMIT 1;
  END IF;
  UPDATE public.tournees
     SET nb_colis = COALESCE(v_nb_colis, 0),
         nb_cartons = COALESCE(v_nb_cartons, 0),
         nb_clients = COALESCE(v_nb_clients, 0),
         chauffeur_nom = COALESCE(v_chauffeur, chauffeur_nom),
         responsable_nom = COALESCE(v_responsable, responsable_nom),
         vehicule_id = COALESCE(v_vehicule_id, vehicule_id),
         updated_at = now()
   WHERE date_tournee = _date AND statut IN ('preparee','en_cours');
  GET DIAGNOSTICS v_updated = ROW_COUNT;

  INSERT INTO public.trigger_execution_log(
    trigger_name, target_date, nb_colis, nb_cartons, nb_clients,
    chauffeur, responsable, immat, affected_rows, message)
  VALUES (
    'recalc_tournee_from_colis', _date, v_nb_colis, v_nb_cartons, v_nb_clients,
    v_chauffeur, v_responsable, v_immat, v_updated,
    CASE WHEN v_updated = 0
         THEN 'Aucune tournée preparee/en_cours pour cette date'
         ELSE NULL END);

  RETURN v_updated;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO public.trigger_execution_log(trigger_name, target_date, affected_rows, message)
    VALUES ('recalc_tournee_from_colis', _date, -1, 'ERROR '||SQLSTATE||': '||SQLERRM);
  RAISE;
END $function$;
