-- Fonction : recalcule les champs dérivés d'une tournée à partir du colisage du jour
CREATE OR REPLACE FUNCTION public.recalc_tournee_from_colis(_date date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nb_colis int;
  v_nb_cartons int;
  v_nb_clients int;
  v_chauffeur text;
  v_responsable text;
  v_immat text;
  v_vehicule_id uuid;
BEGIN
  IF _date IS NULL THEN
    RETURN;
  END IF;

  SELECT count(*)::int, COALESCE(sum(nb_cartons),0)::int
    INTO v_nb_colis, v_nb_cartons
    FROM public.colis WHERE date_colisage = _date;

  SELECT count(DISTINCT c.client_id)::int
    INTO v_nb_clients
    FROM public.colis co
    JOIN public.commandes c ON c.commande_id = co.commande_id
    WHERE co.date_colisage = _date;

  -- Valeur la plus fréquente (mode) pour chaque champ texte
  SELECT livreur_nom INTO v_chauffeur
    FROM public.colis
    WHERE date_colisage = _date AND coalesce(btrim(livreur_nom),'') <> ''
    GROUP BY livreur_nom ORDER BY count(*) DESC LIMIT 1;

  SELECT responsable_nom INTO v_responsable
    FROM public.colis
    WHERE date_colisage = _date AND coalesce(btrim(responsable_nom),'') <> ''
    GROUP BY responsable_nom ORDER BY count(*) DESC LIMIT 1;

  SELECT vehicule INTO v_immat
    FROM public.colis
    WHERE date_colisage = _date AND coalesce(btrim(vehicule),'') <> ''
    GROUP BY vehicule ORDER BY count(*) DESC LIMIT 1;

  IF v_immat IS NOT NULL THEN
    SELECT vehicule_id INTO v_vehicule_id
      FROM public.vehicules WHERE immatriculation ILIKE v_immat LIMIT 1;
  END IF;

  UPDATE public.tournees
     SET nb_colis        = COALESCE(v_nb_colis, 0),
         nb_cartons      = COALESCE(v_nb_cartons, 0),
         nb_clients      = COALESCE(v_nb_clients, 0),
         chauffeur_nom   = COALESCE(v_chauffeur, chauffeur_nom),
         responsable_nom = COALESCE(v_responsable, responsable_nom),
         vehicule_id     = COALESCE(v_vehicule_id, vehicule_id),
         updated_at      = now()
   WHERE date_tournee = _date
     AND statut IN ('preparee','en_cours');
END $$;

-- Trigger sur colis : recalcule pour l'ancienne ET la nouvelle date
CREATE OR REPLACE FUNCTION public.trg_colis_sync_tournee()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalc_tournee_from_colis(OLD.date_colisage);
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.date_colisage IS DISTINCT FROM NEW.date_colisage THEN
    PERFORM public.recalc_tournee_from_colis(OLD.date_colisage);
  END IF;
  PERFORM public.recalc_tournee_from_colis(NEW.date_colisage);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS colis_sync_tournee ON public.colis;
CREATE TRIGGER colis_sync_tournee
AFTER INSERT OR UPDATE OR DELETE ON public.colis
FOR EACH ROW EXECUTE FUNCTION public.trg_colis_sync_tournee();

-- Activer Realtime sur tournees pour propager la mise à jour côté client
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournees;