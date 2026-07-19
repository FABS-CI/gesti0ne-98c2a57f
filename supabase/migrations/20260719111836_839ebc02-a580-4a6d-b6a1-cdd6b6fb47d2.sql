CREATE OR REPLACE FUNCTION public.finaliser_tournee(_tournee_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_statut text;
  v_colis integer;
  v_suivis integer;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'tournees.valider') THEN
    RAISE EXCEPTION 'Accès refusé : permission tournees.valider requise'
      USING ERRCODE = '42501';
  END IF;

  SELECT type_tournee, statut INTO v_type, v_statut
  FROM public.tournees
  WHERE tournee_id = _tournee_id
  FOR UPDATE;

  IF v_statut IS NULL THEN
    RAISE EXCEPTION 'Tournée introuvable';
  END IF;
  IF v_statut = 'annulee' THEN
    RAISE EXCEPTION 'Une tournée annulée ne peut pas être validée';
  END IF;

  SELECT count(*) INTO v_colis
  FROM public.colis
  WHERE tournee_id = _tournee_id;

  IF v_colis = 0 THEN
    RAISE EXCEPTION 'Validation impossible : aucun colis n’est affecté à cette tournée';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.colis
    WHERE tournee_id = _tournee_id AND commande_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Validation impossible : un ou plusieurs colis ne sont rattachés à aucune commande';
  END IF;

  INSERT INTO public.livsuivi_commandes(
    commande_id, tournee_id, type_livraison, ville_destination,
    livreur_nom, vehicule, statut, nb_cartons
  )
  SELECT
    col.commande_id,
    _tournee_id,
    COALESCE(v_type, 'direct'),
    COALESCE(max(col.ville_livraison), max(col.ville_destination)),
    max(col.livreur_nom),
    max(col.vehicule),
    'preparee',
    count(*)::integer
  FROM public.colis col
  WHERE col.tournee_id = _tournee_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.livsuivi_commandes ls
      WHERE ls.tournee_id = _tournee_id
        AND ls.commande_id = col.commande_id
    )
  GROUP BY col.commande_id;

  SELECT count(*) INTO v_suivis
  FROM public.livsuivi_commandes
  WHERE tournee_id = _tournee_id;

  IF v_suivis = 0 THEN
    RAISE EXCEPTION 'Validation impossible : aucun suivi de livraison n’a pu être créé';
  END IF;

  IF v_statut IN ('preparee', 'brouillon') THEN
    UPDATE public.tournees
    SET statut = 'en_cours', updated_at = now()
    WHERE tournee_id = _tournee_id;
    v_statut := 'en_cours';
  END IF;

  RETURN jsonb_build_object(
    'tournee_id', _tournee_id,
    'statut', v_statut,
    'colis', v_colis,
    'suivis', v_suivis
  );
END;
$$;

REVOKE ALL ON FUNCTION public.finaliser_tournee(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finaliser_tournee(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finaliser_tournee(uuid) TO service_role;