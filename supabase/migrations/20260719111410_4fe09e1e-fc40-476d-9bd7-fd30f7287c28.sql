CREATE OR REPLACE FUNCTION public.affecter_colis_tournee(_tournee_id uuid, _colis_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expected integer;
  v_updated integer;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'tournees.valider')
     AND NOT public.has_permission(auth.uid(), 'tournees.creer') THEN
    RAISE EXCEPTION 'Accès refusé : permission de gestion des tournées requise'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.tournees WHERE tournee_id = _tournee_id) THEN
    RAISE EXCEPTION 'Tournée introuvable';
  END IF;

  v_expected := COALESCE(array_length(_colis_ids, 1), 0);
  IF v_expected = 0 THEN
    RAISE EXCEPTION 'Aucun colis sélectionné';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.colis c
    WHERE c.colis_id = ANY(_colis_ids)
      AND c.tournee_id IS NOT NULL
      AND c.tournee_id <> _tournee_id
  ) THEN
    RAISE EXCEPTION 'Un ou plusieurs colis sont déjà affectés à une autre tournée';
  END IF;

  UPDATE public.colis c
  SET tournee_id = _tournee_id,
      commande_id = COALESCE(c.commande_id, bl.commande_id),
      updated_at = now()
  FROM public.bons_livraison bl
  WHERE c.colis_id = ANY(_colis_ids)
    AND bl.bl_id = c.bl_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> v_expected THEN
    RAISE EXCEPTION 'Affectation incomplète : % colis sur %', v_updated, v_expected;
  END IF;

  RETURN jsonb_build_object('tournee_id', _tournee_id, 'colis_affectes', v_updated);
END;
$$;

REVOKE ALL ON FUNCTION public.affecter_colis_tournee(uuid, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.affecter_colis_tournee(uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.affecter_colis_tournee(uuid, uuid[]) TO service_role;

DO $$
DECLARE
  v_tournee uuid;
  v_colis_ids uuid[];
BEGIN
  SELECT tournee_id INTO v_tournee
  FROM public.tournees
  WHERE reference = 'TRN-20260719-2394'
  LIMIT 1;

  IF v_tournee IS NULL THEN
    RETURN;
  END IF;

  SELECT array_agg(c.colis_id ORDER BY c.reference)
  INTO v_colis_ids
  FROM public.colis c
  WHERE c.bl_id IN (
    '65b4a827-e2fd-43ea-aba8-3779addf65c2'::uuid,
    'c1ead32c-8212-4124-950f-3a3fe01d9354'::uuid
  );

  UPDATE public.colis c
  SET tournee_id = v_tournee,
      commande_id = COALESCE(c.commande_id, bl.commande_id),
      updated_at = now()
  FROM public.bons_livraison bl
  WHERE c.colis_id = ANY(v_colis_ids)
    AND bl.bl_id = c.bl_id;

  INSERT INTO public.livsuivi_commandes(
    commande_id, tournee_id, type_livraison, ville_destination,
    livreur_nom, vehicule, statut, nb_cartons
  )
  SELECT
    c.commande_id,
    v_tournee,
    COALESCE(t.type_tournee, 'direct'),
    COALESCE(max(c.ville_livraison), max(c.ville_destination)),
    max(c.livreur_nom),
    max(c.vehicule),
    'preparee',
    count(*)::integer
  FROM public.colis c
  JOIN public.tournees t ON t.tournee_id = v_tournee
  WHERE c.tournee_id = v_tournee
    AND c.commande_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.livsuivi_commandes ls
      WHERE ls.tournee_id = v_tournee AND ls.commande_id = c.commande_id
    )
  GROUP BY c.commande_id, t.type_tournee;
END;
$$;