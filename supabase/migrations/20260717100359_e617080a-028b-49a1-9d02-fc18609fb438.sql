
CREATE OR REPLACE FUNCTION public.confirmer_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_statut text;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.receptionner') THEN
    RAISE EXCEPTION 'Permission refusée : achats.receptionner' USING ERRCODE = '42501';
  END IF;
  SELECT statut INTO v_statut FROM public.achats WHERE achat_id = _achat_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Achat introuvable'; END IF;
  IF v_statut NOT IN ('brouillon','en_attente','en_attente_validation') THEN
    RAISE EXCEPTION 'Achat non confirmable (statut actuel: %)', v_statut;
  END IF;
  UPDATE public.achats SET statut = 'confirme', updated_at = now() WHERE achat_id = _achat_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
RETURNS achats LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  a public.achats;
  l jsonb;
  v_total numeric := 0;
  v_qty int := 0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_date date := COALESCE((_payload->>'date_achat')::date, current_date);
  v_qte int;
  v_actuel int;
  v_dup_count int;
  v_exercice uuid;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.creer') THEN
    RAISE EXCEPTION 'Permission refusée : achats.creer' USING ERRCODE = '42501';
  END IF;

  IF v_depot IS NULL THEN
    RAISE EXCEPTION 'Le dépôt est obligatoire pour un approvisionnement';
  END IF;

  SELECT COUNT(*) INTO v_dup_count FROM (
    SELECT (x->>'produit_id')::uuid AS pid
    FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) x
    WHERE NULLIF(x->>'produit_id','') IS NOT NULL
    GROUP BY (x->>'produit_id')::uuid
    HAVING COUNT(*) > 1
  ) d;
  IF v_dup_count > 0 THEN
    RAISE EXCEPTION 'Un même produit ne peut pas être ajouté plusieurs fois dans un approvisionnement';
  END IF;

  SELECT exercice_id INTO v_exercice
  FROM public.exercices_comptables
  WHERE v_date BETWEEN date_debut AND date_fin
  ORDER BY (statut = 'actif') DESC LIMIT 1;

  IF v_exercice IS NULL THEN
    SELECT exercice_id INTO v_exercice FROM public.exercices_comptables WHERE statut = 'actif' LIMIT 1;
  END IF;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_total := v_total + (COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0));
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;

  INSERT INTO public.achats(fournisseur_id, fournisseur_nom, libelle, montant, statut, date_achat,
    reference_fournisseur, notes, total_quantite, depot_id, exercice_id, created_by, created_by_nom)
  SELECT (_payload->>'fournisseur_id')::uuid, f.raison_sociale, 'Approvisionnement', v_total, 'recu',
    v_date, _payload->>'reference_fournisseur', _payload->>'notes', v_qty, v_depot, v_exercice, auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email')
  FROM public.fournisseurs f
  WHERE f.fournisseur_id = (_payload->>'fournisseur_id')::uuid
  RETURNING * INTO a;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.achat_lignes(achat_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
    VALUES(a.achat_id, NULLIF(l->>'produit_id','')::uuid, l->>'reference_produit', l->>'designation',
      COALESCE((l->>'quantite')::int,0), COALESCE((l->>'prix_unitaire')::numeric,0),
      COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0));

    IF NULLIF(l->>'produit_id','') IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES((l->>'produit_id')::uuid, v_depot, 0)
      ON CONFLICT (produit_id, depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id = (l->>'produit_id')::uuid AND depot_id = v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot,
        (COALESCE(v_actuel,0) + v_qte)::numeric,
        'Approvisionnement ' || a.reference
      );
    END IF;
  END LOOP;

  RETURN a;
END
$function$;

CREATE OR REPLACE FUNCTION public.modifier_approvisionnement(_achat_id uuid, _payload jsonb)
RETURNS SETOF achats LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_ligne jsonb; v_total numeric := 0;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.modifier') THEN
    RAISE EXCEPTION 'Permission refusée : achats.modifier' USING ERRCODE = '42501';
  END IF;

  UPDATE public.achats SET
    fournisseur_id = COALESCE(NULLIF(_payload->>'fournisseur_id','')::uuid, fournisseur_id),
    depot_id = COALESCE(NULLIF(_payload->>'depot_id','')::uuid, depot_id),
    libelle = COALESCE(_payload->>'libelle', libelle),
    date_achat = COALESCE((_payload->>'date_achat')::date, date_achat),
    notes = COALESCE(_payload->>'notes', notes)
  WHERE achat_id = _achat_id;

  IF _payload ? 'lignes' THEN
    DELETE FROM public.achat_lignes WHERE achat_id = _achat_id;
    FOR v_ligne IN SELECT * FROM jsonb_array_elements(_payload->'lignes') LOOP
      INSERT INTO public.achat_lignes(achat_id, produit_id, reference_produit, designation,
        quantite, prix_unitaire, total_ligne)
      VALUES (_achat_id,
        NULLIF(v_ligne->>'produit_id','')::uuid,
        v_ligne->>'reference_produit',
        COALESCE(v_ligne->>'designation',''),
        COALESCE((v_ligne->>'quantite')::numeric, 0),
        COALESCE((v_ligne->>'prix_unitaire')::numeric, 0),
        COALESCE((v_ligne->>'quantite')::numeric,0) * COALESCE((v_ligne->>'prix_unitaire')::numeric,0));
      v_total := v_total + COALESCE((v_ligne->>'quantite')::numeric,0) * COALESCE((v_ligne->>'prix_unitaire')::numeric,0);
    END LOOP;
    UPDATE public.achats SET montant = v_total WHERE achat_id = _achat_id;
  END IF;

  RETURN QUERY SELECT * FROM public.achats WHERE achat_id = _achat_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.payer_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.payer') THEN
    RAISE EXCEPTION 'Permission refusée : achats.payer' USING ERRCODE = '42501';
  END IF;
  UPDATE public.achats SET statut = 'paye' WHERE achat_id = _achat_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Achat introuvable'; END IF;
END; $function$;

CREATE OR REPLACE FUNCTION public.receptionner_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_statut text; v_depot uuid; r record;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.receptionner') THEN
    RAISE EXCEPTION 'Permission refusée : achats.receptionner' USING ERRCODE = '42501';
  END IF;

  SELECT statut, depot_id INTO v_statut, v_depot FROM public.achats WHERE achat_id = _achat_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Achat introuvable'; END IF;
  IF v_statut = 'receptionne' THEN RAISE EXCEPTION 'Achat déjà réceptionné'; END IF;

  IF v_depot IS NOT NULL THEN
    FOR r IN SELECT produit_id, quantite FROM public.achat_lignes
             WHERE achat_id = _achat_id AND produit_id IS NOT NULL LOOP
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES (r.produit_id, v_depot, r.quantite)
      ON CONFLICT (produit_id, depot_id) DO UPDATE
        SET quantite = public.stocks_depots.quantite + EXCLUDED.quantite,
            updated_at = now();
      INSERT INTO public.stock_mouvements(produit_id, depot_id, type, quantite,
        quantite_entree, quantite_sortie, stock_resultant, origine, document_id, user_id)
      SELECT r.produit_id, v_depot, 'entree', r.quantite, r.quantite, 0, quantite,
             'achat', _achat_id, auth.uid()
      FROM public.stocks_depots WHERE produit_id = r.produit_id AND depot_id = v_depot;
    END LOOP;
  END IF;

  UPDATE public.achats SET statut = 'receptionne' WHERE achat_id = _achat_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.supprimer_achat(_achat_id uuid, _motif text DEFAULT NULL::text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.supprimer') THEN
    RAISE EXCEPTION 'Permission refusée : achats.supprimer' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.achats WHERE achat_id = _achat_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.supprimer_fournisseur(_fournisseur_id uuid, _motif text DEFAULT NULL::text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_used int;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'fournisseurs.supprimer') THEN
    RAISE EXCEPTION 'Permission refusée : fournisseurs.supprimer' USING ERRCODE = '42501';
  END IF;
  SELECT count(*) INTO v_used FROM public.achats WHERE fournisseur_id = _fournisseur_id;
  IF v_used > 0 THEN
    RAISE EXCEPTION 'Fournisseur utilisé dans % achat(s)', v_used;
  END IF;
  DELETE FROM public.fournisseurs WHERE fournisseur_id = _fournisseur_id;
END; $function$;
