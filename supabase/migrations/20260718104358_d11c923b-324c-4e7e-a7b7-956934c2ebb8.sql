
CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
 RETURNS SETOF specimens
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('SPC','public.specimens','reference');
  v_num text := v_ref;
  v_l jsonb;
  v_qte_totale numeric := 0;
  v_nb_produits int := 0;
  v_client_nom text;
  v_created_by_nom text;
  v_depot uuid;
  v_produit uuid;
  v_qte numeric;
  v_new_stock numeric;
BEGIN
  PERFORM public.assert_permission('specimens.creer');

  IF NULLIF(_payload->>'client_id','') IS NOT NULL THEN
    SELECT nom INTO v_client_nom FROM public.clients WHERE client_id = (_payload->>'client_id')::uuid;
  END IF;
  v_created_by_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  v_depot := NULLIF(_payload->>'depot_id','')::uuid;
  IF v_depot IS NULL THEN
    SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal AND actif LIMIT 1;
  END IF;

  INSERT INTO public.specimens(
    reference, numero, client_id, client_nom,
    etablissement, representant_nom, telephone, ville, adresse,
    donneur_nom, motif, observations,
    date_envoi, statut,
    total_quantite, nb_produits,
    depot_id, created_by,
    gestionnaire_id, gestionnaire_nom,
    quantite, designation
  ) VALUES (
    v_ref, v_num,
    NULLIF(_payload->>'client_id','')::uuid,
    COALESCE(_payload->>'client_nom', v_client_nom),
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    _payload->>'donneur_nom',
    _payload->>'motif',
    _payload->>'observations',
    COALESCE((_payload->>'date_envoi')::date, current_date),
    'enregistre',
    0, 0,
    v_depot,
    auth.uid(),
    auth.uid(), v_created_by_nom,
    0, ''
  )
  RETURNING specimen_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_produit := NULLIF(v_l->>'produit_id','')::uuid;
    v_qte := COALESCE((v_l->>'quantite')::numeric, 0);

    INSERT INTO public.specimen_lignes(
      specimen_id, produit_id, reference_produit, designation, quantite
    ) VALUES (
      v_id, v_produit,
      v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''),
      v_qte
    );
    v_qte_totale := v_qte_totale + v_qte;
    v_nb_produits := v_nb_produits + 1;

    -- Décrément stock (sortie physique — remise gratuite)
    IF v_produit IS NOT NULL AND v_depot IS NOT NULL AND v_qte > 0 THEN
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES (v_produit, v_depot, -v_qte)
      ON CONFLICT (produit_id, depot_id) DO UPDATE
        SET quantite = public.stocks_depots.quantite - v_qte, updated_at = now();
      SELECT quantite INTO v_new_stock FROM public.stocks_depots
        WHERE produit_id=v_produit AND depot_id=v_depot;
      INSERT INTO public.stock_mouvements(
        produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
        stock_resultant, origine, document_id, document_reference, document_table,
        user_id, motif
      ) VALUES (
        v_produit, v_depot, 'sortie', v_qte, 0, v_qte, v_new_stock,
        'specimen', v_id, v_ref, 'specimens', auth.uid(),
        'Spécimen — remise gratuite'
      );
    END IF;
  END LOOP;

  UPDATE public.specimens
     SET total_quantite = v_qte_totale,
         nb_produits    = v_nb_produits
   WHERE specimen_id = v_id;

  RETURN QUERY SELECT * FROM public.specimens WHERE specimen_id = v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.annuler_specimen(_specimen_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_statut text;
  v_depot uuid;
  v_ref text;
  r record;
  v_new_stock numeric;
BEGIN
  PERFORM public.assert_permission('specimens.annuler');

  SELECT statut, depot_id, reference INTO v_statut, v_depot, v_ref
    FROM public.specimens WHERE specimen_id = _specimen_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Spécimen introuvable'; END IF;
  IF v_statut = 'annule' THEN RETURN; END IF;

  -- Restauration du stock
  IF v_depot IS NOT NULL THEN
    FOR r IN SELECT produit_id, quantite FROM public.specimen_lignes WHERE specimen_id = _specimen_id LOOP
      IF r.produit_id IS NOT NULL AND r.quantite > 0 THEN
        INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
        VALUES (r.produit_id, v_depot, r.quantite)
        ON CONFLICT (produit_id, depot_id) DO UPDATE
          SET quantite = public.stocks_depots.quantite + r.quantite, updated_at = now();
        SELECT quantite INTO v_new_stock FROM public.stocks_depots
          WHERE produit_id=r.produit_id AND depot_id=v_depot;
        INSERT INTO public.stock_mouvements(
          produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie,
          stock_resultant, origine, document_id, document_reference, document_table,
          user_id, motif
        ) VALUES (
          r.produit_id, v_depot, 'entree', r.quantite, r.quantite, 0, v_new_stock,
          'specimen_annulation', _specimen_id, v_ref, 'specimens', auth.uid(),
          'Annulation spécimen — restauration stock'
        );
      END IF;
    END LOOP;
  END IF;

  UPDATE public.specimens
     SET statut = 'annule', notes = COALESCE(_motif, notes), updated_at = now()
   WHERE specimen_id = _specimen_id;
END;
$function$;
