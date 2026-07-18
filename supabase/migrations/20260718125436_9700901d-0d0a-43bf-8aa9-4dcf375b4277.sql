
-- Comble le trou d'impact stock pour les incidents (casse, perte, vol, détérioration)
-- et pour leur annulation.

CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
RETURNS SETOF public.incidents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('INC','public.incidents','reference');
  v_l jsonb;
  v_qte numeric := 0;
  v_nb int := 0;
  v_nom text;
  v_type text := COALESCE(_payload->>'type_incident','autre');
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_impact_stock boolean;
  v_pid uuid;
  v_q numeric;
  v_stock_res numeric;
BEGIN
  PERFORM public.assert_permission('incidents.creer');

  v_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  -- Un incident impacte le stock si c'est une perte physique
  v_impact_stock := v_type IN ('casse','perte','vol','deterioration','destruction')
                     AND v_depot IS NOT NULL;

  INSERT INTO public.incidents(
    reference, numero, type_incident, gravite, description,
    date_incident, statut, motif, observations, depot_id,
    responsable_id, responsable_nom, total_quantite, nb_produits, created_by
  ) VALUES (
    v_ref, v_ref, v_type,
    COALESCE(_payload->>'gravite','mineur'),
    _payload->>'description',
    COALESCE((_payload->>'date_incident')::timestamptz, now()),
    'declare',
    _payload->>'motif',
    _payload->>'observations',
    v_depot,
    auth.uid(), v_nom, 0, 0, auth.uid()
  ) RETURNING incident_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_pid := NULLIF(v_l->>'produit_id','')::uuid;
    v_q   := COALESCE((v_l->>'quantite')::numeric, 0);

    INSERT INTO public.incident_lignes(incident_id, produit_id, reference_produit, designation, quantite)
    VALUES (v_id, v_pid, v_l->>'reference_produit', COALESCE(v_l->>'designation',''), v_q);

    v_qte := v_qte + v_q;
    v_nb  := v_nb + 1;

    IF v_impact_stock AND v_pid IS NOT NULL AND v_q > 0 THEN
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES (v_pid, v_depot, -v_q)
      ON CONFLICT (produit_id, depot_id)
      DO UPDATE SET quantite = public.stocks_depots.quantite - v_q,
                    updated_at = now()
      RETURNING quantite INTO v_stock_res;

      INSERT INTO public.stock_mouvements(
        produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
        stock_resultant, motif, origine, document_id, document_reference, document_table,
        user_id, user_nom
      ) VALUES (
        v_pid, v_depot, 'sortie', v_q, 0, v_q,
        COALESCE(v_stock_res, 0),
        COALESCE(_payload->>'motif', v_type),
        'incident', v_id, v_ref, 'incidents',
        auth.uid(), v_nom
      );
    END IF;
  END LOOP;

  UPDATE public.incidents
     SET total_quantite = v_qte, nb_produits = v_nb
   WHERE incident_id = v_id;

  RETURN QUERY SELECT * FROM public.incidents WHERE incident_id = v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.annuler_incident(_incident_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inc record;
  v_l record;
  v_impact boolean;
  v_stock_res numeric;
  v_nom text;
BEGIN
  PERFORM public.assert_permission('incidents.annuler');

  SELECT * INTO v_inc FROM public.incidents WHERE incident_id = _incident_id FOR UPDATE;
  IF v_inc IS NULL THEN
    RAISE EXCEPTION 'Incident introuvable';
  END IF;

  IF v_inc.statut = 'annule' THEN
    RETURN;
  END IF;

  v_impact := v_inc.type_incident IN ('casse','perte','vol','deterioration','destruction')
              AND v_inc.depot_id IS NOT NULL;
  v_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  IF v_impact THEN
    FOR v_l IN
      SELECT produit_id, quantite FROM public.incident_lignes
      WHERE incident_id = _incident_id AND produit_id IS NOT NULL AND quantite > 0
    LOOP
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES (v_l.produit_id, v_inc.depot_id, v_l.quantite)
      ON CONFLICT (produit_id, depot_id)
      DO UPDATE SET quantite = public.stocks_depots.quantite + v_l.quantite,
                    updated_at = now()
      RETURNING quantite INTO v_stock_res;

      INSERT INTO public.stock_mouvements(
        produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
        stock_resultant, motif, origine, document_id, document_reference, document_table,
        user_id, user_nom
      ) VALUES (
        v_l.produit_id, v_inc.depot_id, 'entree', v_l.quantite, v_l.quantite, 0,
        COALESCE(v_stock_res, 0),
        'Annulation incident ' || v_inc.reference,
        'incident_annulation', _incident_id, v_inc.reference, 'incidents',
        auth.uid(), v_nom
      );
    END LOOP;
  END IF;

  UPDATE public.incidents
     SET statut = 'annule', updated_at = now()
   WHERE incident_id = _incident_id;
END;
$$;
