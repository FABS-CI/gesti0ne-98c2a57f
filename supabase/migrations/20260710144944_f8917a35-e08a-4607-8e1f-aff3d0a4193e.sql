CREATE OR REPLACE FUNCTION public.modifier_approvisionnement(_achat_id uuid, _payload jsonb)
 RETURNS achats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_is_admin boolean;
  v_a public.achats;
  v_ex_cloture boolean := false;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_fourn uuid := NULLIF(_payload->>'fournisseur_id','')::uuid;
  v_total numeric := 0;
  v_qty int := 0;
  l jsonb;
  v_actuel int;
  v_qte int;
  rec record;
BEGIN
  PERFORM public.assert_permission('achats.modifier');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  IF v_depot IS NULL THEN RAISE EXCEPTION 'Le dépôt est obligatoire'; END IF;
  IF v_fourn IS NULL THEN RAISE EXCEPTION 'Le fournisseur est obligatoire'; END IF;

  SELECT * INTO v_a FROM public.achats WHERE achat_id=_achat_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Approvisionnement introuvable'; END IF;

  v_is_admin := public.has_role(v_user,'super_admin'::public.app_role);

  IF v_a.exercice_id IS NOT NULL THEN
    SELECT (statut='cloture') INTO v_ex_cloture FROM public.exercices WHERE exercice_id=v_a.exercice_id;
    v_ex_cloture := COALESCE(v_ex_cloture,false);
  END IF;

  IF NOT v_is_admin THEN
    IF v_a.statut IN ('paye','annule') THEN
      RAISE EXCEPTION 'Modification interdite : l''approvisionnement est % — réservé au super_admin.', v_a.statut
        USING ERRCODE='check_violation';
    END IF;
    IF v_ex_cloture THEN
      RAISE EXCEPTION 'Modification interdite : exercice comptable clôturé.' USING ERRCODE='check_violation';
    END IF;
  END IF;

  -- 1) Annuler les mouvements de stock précédents (soustraire les quantités déjà ajoutées)
  FOR rec IN
    SELECT al.produit_id, al.quantite, COALESCE(sm.depot_id, v_a.depot_id) AS depot_id
    FROM public.achat_lignes al
    LEFT JOIN LATERAL (
      SELECT depot_id FROM public.stock_mouvements
      WHERE document_id = _achat_id AND document_table='achats' AND produit_id=al.produit_id
      ORDER BY created_at DESC LIMIT 1
    ) sm ON true
    WHERE al.achat_id=_achat_id AND al.produit_id IS NOT NULL
  LOOP
    IF rec.depot_id IS NOT NULL THEN
      INSERT INTO public.stocks_depots(produit_id,depot_id,quantite) VALUES(rec.produit_id,rec.depot_id,0)
        ON CONFLICT(produit_id,depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id=rec.produit_id AND depot_id=rec.depot_id FOR UPDATE;
      PERFORM public.ajuster_stock_depot(
        rec.produit_id, rec.depot_id, GREATEST(v_actuel - rec.quantite, 0),
        'Annulation approvisionnement (modif) '||v_a.reference,
        'modif_approvisionnement', v_a.achat_id, v_a.reference, 'achats', NULL
      );
    END IF;
  END LOOP;

  -- 2) Purger anciennes lignes / mouvements / écritures
  SET LOCAL app.allow_stock_mouvement_delete = 'on';
  DELETE FROM public.stock_mouvements WHERE document_id=_achat_id AND document_table='achats';
  RESET app.allow_stock_mouvement_delete;
  DELETE FROM public.ecritures_comptables WHERE source_type='achat' AND source_id=_achat_id;
  DELETE FROM public.achat_lignes WHERE achat_id=_achat_id;

  -- 3) Recalculer totaux
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_total := v_total + (COALESCE((l->>'quantite')::int,0)*COALESCE((l->>'prix_unitaire')::numeric,0));
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;

  -- 4) Mettre à jour l'entête
  UPDATE public.achats SET
    fournisseur_id = v_fourn,
    fournisseur_nom = (SELECT raison_sociale FROM public.fournisseurs WHERE fournisseur_id=v_fourn),
    depot_id = v_depot,
    date_achat = COALESCE((_payload->>'date_achat')::date, v_a.date_achat),
    reference_fournisseur = _payload->>'reference_fournisseur',
    notes = _payload->>'notes',
    montant = v_total,
    total_quantite = v_qty,
    updated_at = now()
  WHERE achat_id=_achat_id
  RETURNING * INTO v_a;

  -- 5) Réinsérer lignes et régénérer stock
  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.achat_lignes(achat_id,produit_id,reference_produit,designation,quantite,prix_unitaire,total_ligne)
    VALUES(v_a.achat_id, NULLIF(l->>'produit_id','')::uuid, l->>'reference_produit', l->>'designation',
      COALESCE((l->>'quantite')::int,0), COALESCE((l->>'prix_unitaire')::numeric,0),
      COALESCE((l->>'quantite')::int,0)*COALESCE((l->>'prix_unitaire')::numeric,0));
    IF NULLIF(l->>'produit_id','') IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      INSERT INTO public.stocks_depots(produit_id,depot_id,quantite)
        VALUES((l->>'produit_id')::uuid, v_depot, 0)
        ON CONFLICT(produit_id,depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id=(l->>'produit_id')::uuid AND depot_id=v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot, v_actuel + v_qte,
        'Approvisionnement (modif) '||v_a.reference,
        'approvisionnement', v_a.achat_id, v_a.reference, 'achats', NULL
      );
    END IF;
  END LOOP;

  INSERT INTO public.audit_logs(user_id,user_email,action,table_name,record_id,old_values,new_values)
  VALUES (v_user, COALESCE((SELECT email FROM auth.users WHERE id=v_user),''),
    'achat_modifie','achats',_achat_id::text, NULL, to_jsonb(v_a));

  RETURN v_a;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.modifier_approvisionnement(uuid, jsonb) TO authenticated;