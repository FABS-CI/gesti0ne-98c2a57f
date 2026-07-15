
CREATE OR REPLACE FUNCTION public.trg_colis_sync_tournee_fn()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_u int;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_u := public.recalc_tournee_from_colis(OLD.date_colisage::date);
    RAISE LOG '[trg_colis_sync] DELETE colis_id=% date=% updated=%', OLD.colis_id, OLD.date_colisage, v_u;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    v_u := public.recalc_tournee_from_colis(OLD.date_colisage::date);
    RAISE LOG '[trg_colis_sync] UPDATE colis_id=% old_date=% updated=%', OLD.colis_id, OLD.date_colisage, v_u;
    IF NEW.date_colisage::date IS DISTINCT FROM OLD.date_colisage::date THEN
      v_u := public.recalc_tournee_from_colis(NEW.date_colisage::date);
      RAISE LOG '[trg_colis_sync] UPDATE colis_id=% new_date=% updated=%', NEW.colis_id, NEW.date_colisage, v_u;
    END IF;
    RETURN NEW;
  ELSE
    v_u := public.recalc_tournee_from_colis(NEW.date_colisage::date);
    RAISE LOG '[trg_colis_sync] INSERT colis_id=% date=% updated=%', NEW.colis_id, NEW.date_colisage, v_u;
    RETURN NEW;
  END IF;
END $$;

-- La fonction de recalcul compare également date_colisage avec un paramètre date :
-- ajoutons un cast explicite dans les filtres pour éviter tout mismatch de type.
CREATE OR REPLACE FUNCTION public.recalc_tournee_from_colis(_date date)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_nb_colis int; v_nb_cartons int; v_nb_clients int;
  v_chauffeur text; v_responsable text; v_immat text;
  v_vehicule_id uuid; v_updated int := 0;
BEGIN
  IF _date IS NULL THEN RAISE LOG '[recalc_tournee] date NULL, skip'; RETURN 0; END IF;
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
  RAISE LOG '[recalc_tournee] date=% colis=% cartons=% clients=% chauffeur=% resp=% immat=% updated=%',
    _date, v_nb_colis, v_nb_cartons, v_nb_clients, v_chauffeur, v_responsable, v_immat, v_updated;
  RETURN v_updated;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[recalc_tournee] ERROR date=% sqlstate=% sqlerrm=%', _date, SQLSTATE, SQLERRM;
  RAISE;
END $function$;
