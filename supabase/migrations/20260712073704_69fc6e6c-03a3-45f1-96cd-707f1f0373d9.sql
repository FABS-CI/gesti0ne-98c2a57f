
CREATE OR REPLACE FUNCTION public.cloturer_tournee(_tournee_id uuid)
RETURNS public.tournees
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_t public.tournees;
  v_missing text := '';
  v_nb_colis int;
  r record;
  v_type public.livsuivi_type;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.assert_permission('tournees.creer');

  SELECT * INTO v_t FROM public.tournees WHERE tournee_id = _tournee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tournée introuvable'; END IF;

  IF v_t.statut = 'terminee' THEN
    RETURN v_t;
  END IF;
  IF v_t.statut = 'annulee' THEN
    RAISE EXCEPTION 'Tournée annulée : clôture impossible';
  END IF;

  IF v_t.chauffeur_nom IS NULL OR btrim(v_t.chauffeur_nom) = '' THEN
    v_missing := v_missing || ' chauffeur';
  END IF;
  IF v_t.vehicule_id IS NULL THEN v_missing := v_missing || ' véhicule'; END IF;
  IF v_t.date_tournee IS NULL THEN v_missing := v_missing || ' date_départ'; END IF;
  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Champs obligatoires manquants :%', v_missing;
  END IF;

  SELECT count(*) INTO v_nb_colis FROM public.colis WHERE tournee_id = _tournee_id;
  IF v_nb_colis = 0 THEN
    RAISE EXCEPTION 'Aucun colis affecté à la tournée';
  END IF;

  -- Création/mise à jour idempotente du suivi de livraison pour chaque commande.
  FOR r IN
    SELECT DISTINCT c.commande_id, c.bl_id, c.mode_acheminement,
           count(*) OVER (PARTITION BY c.commande_id) AS nb_cartons
      FROM public.colis c
     WHERE c.tournee_id = _tournee_id
       AND c.commande_id IS NOT NULL
  LOOP
    v_type := CASE WHEN r.mode_acheminement = 'expedition'
                   THEN 'expedition'::public.livsuivi_type
                   ELSE 'direct'::public.livsuivi_type END;
    INSERT INTO public.livsuivi_commandes(commande_id, type_livraison, statut, bl_id, tournee_id, nb_cartons, derniere_maj)
    VALUES (r.commande_id, v_type, 'preparee'::public.livsuivi_statut, r.bl_id, _tournee_id, r.nb_cartons, now())
    ON CONFLICT (commande_id) DO UPDATE
      SET tournee_id     = EXCLUDED.tournee_id,
          type_livraison = EXCLUDED.type_livraison,
          bl_id          = EXCLUDED.bl_id,
          nb_cartons     = EXCLUDED.nb_cartons,
          derniere_maj   = now();
  END LOOP;

  UPDATE public.tournees
     SET statut       = 'terminee',
         cloture_mode = COALESCE(cloture_mode, 'manuelle'),
         cloture_at   = COALESCE(cloture_at, now()),
         cloture_by   = COALESCE(cloture_by, auth.uid())
   WHERE tournee_id = _tournee_id
  RETURNING * INTO v_t;

  RETURN v_t;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cloturer_tournee(uuid) TO authenticated;
