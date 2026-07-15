-- 1. Suppression du trigger qui crée le suivi dès le colisage
DROP TRIGGER IF EXISTS trg_livsuivi_from_bl ON public.bons_livraison;
DROP FUNCTION IF EXISTS public.livsuivi_from_bl();

-- 2. Suppression du système "tournée legacy" (table vide, UI déjà redirigée)
DROP FUNCTION IF EXISTS public.livsuivi_creer_tournee(jsonb);
ALTER TABLE public.livsuivi_commandes DROP CONSTRAINT IF EXISTS livsuivi_commandes_tournee_id_fkey;
DROP TABLE IF EXISTS public.livsuivi_tournees CASCADE;

-- 3. Rattacher livsuivi_commandes.tournee_id à la vraie table tournees
ALTER TABLE public.livsuivi_commandes
  ADD CONSTRAINT livsuivi_commandes_tournee_id_fkey
  FOREIGN KEY (tournee_id) REFERENCES public.tournees(tournee_id) ON DELETE SET NULL;

-- 4. Contrainte anti-réaffectation : un colis affecté à une tournée ne peut plus changer de tournée
CREATE OR REPLACE FUNCTION public.trg_colis_tournee_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.tournee_id IS NOT NULL
     AND NEW.tournee_id IS NOT NULL
     AND OLD.tournee_id <> NEW.tournee_id THEN
    RAISE EXCEPTION 'Un colis déjà affecté à une tournée ne peut pas être déplacé vers une autre tournée';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_colis_tournee_immutable ON public.colis;
CREATE TRIGGER trg_colis_tournee_immutable
BEFORE UPDATE OF tournee_id ON public.colis
FOR EACH ROW EXECUTE FUNCTION public.trg_colis_tournee_immutable();

-- 5. RPC creer_colisage — retire le bloc de création livsuivi_commandes
CREATE OR REPLACE FUNCTION public.creer_colisage(_bl_id uuid, _payload jsonb)
 RETURNS SETOF colis
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bl record; v_nb int := GREATEST(COALESCE((_payload->>'nb_cartons')::int, 1), 1);
  v_mode text := _payload->>'mode_acheminement';
  v_responsable text := COALESCE(_payload->>'responsable_nom', auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  v_client_nom text; i int; v_ref text; v_liv uuid;
  v_new_snapshot jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.assert_permission('colisage.creer');
  IF v_mode NOT IN ('livraison','expedition') THEN
    RAISE EXCEPTION 'Mode d''acheminement invalide (livraison|expedition)';
  END IF;
  SELECT bl.*, c.client_nom AS cnom INTO v_bl FROM public.bons_livraison bl
    LEFT JOIN public.commandes c ON c.commande_id = bl.commande_id WHERE bl.bl_id = _bl_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de livraison introuvable'; END IF;
  v_client_nom := COALESCE(v_bl.cnom, '');

  DELETE FROM public.colis WHERE bl_id = _bl_id;
  FOR i IN 1..v_nb LOOP
    v_ref := v_bl.reference || '-C' || lpad(i::text, 2, '0');
    INSERT INTO public.colis(reference, destinataire, contenu, transporteur, date_envoi, statut,
      bl_id, commande_id, numero_carton, nb_cartons, responsable_id, responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule, quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone, observations, date_colisage)
    VALUES (v_ref, v_client_nom, 'Carton '||i||'/'||v_nb||' — BL '||v_bl.reference,
      CASE WHEN v_mode='expedition' THEN _payload->>'gare_depart' ELSE _payload->>'livreur_nom' END,
      COALESCE((_payload->>'date_colisage')::date, current_date), 'en_preparation',
      _bl_id, v_bl.commande_id, i, v_nb, auth.uid(), v_responsable, v_mode,
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      _payload->>'observations', COALESCE((_payload->>'date_colisage')::timestamptz, now()));
  END LOOP;

  UPDATE public.bons_livraison SET statut = 'colisage_termine', updated_at = now() WHERE bl_id = _bl_id;

  IF v_bl.commande_id IS NOT NULL THEN
    SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = v_bl.commande_id;
    IF v_liv IS NULL THEN
      PERFORM public.creer_livraison_commande(v_bl.commande_id);
      SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = v_bl.commande_id;
    END IF;
    UPDATE public.livraisons_commande SET
      statut='colisage_termine', bl_id=_bl_id,
      transporteur = COALESCE(_payload->>'livreur_nom', _payload->>'gare_depart'),
      chauffeur_nom = _payload->>'livreur_nom',
      vehicule = _payload->>'vehicule',
      ville_livraison = COALESCE(_payload->>'ville_livraison', _payload->>'ville_destination', ville_livraison),
      nb_cartons = v_nb, derniere_maj = now()
      WHERE livraison_id = v_liv;
    PERFORM public.recalculer_livraison_commande(v_liv);
    INSERT INTO public.livraison_commande_historique(livraison_id, nouveau_statut, commentaire, user_id, user_nom)
    VALUES (v_liv, 'colisage_termine', 'Colisage validé ('||v_nb||' carton(s))', auth.uid(), v_responsable);
    -- NOTE: création livsuivi_commandes déplacée dans finaliser_tournee.
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(c.*) ORDER BY c.numero_carton), '[]'::jsonb)
    INTO v_new_snapshot
  FROM public.colis c
  WHERE c.bl_id = _bl_id;

  UPDATE public.colisage_modifications_historique h
     SET nouvelles_valeurs = v_new_snapshot,
         date_revalidation = now()
   WHERE h.id = (
     SELECT id FROM public.colisage_modifications_historique
      WHERE bl_id = _bl_id AND date_revalidation IS NULL
      ORDER BY date_modification DESC
      LIMIT 1
   );

  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END;
$function$;

-- 6. RPC creer_colisage_manuel — retire le bloc de création livsuivi_commandes
CREATE OR REPLACE FUNCTION public.creer_colisage_manuel(_bl_id uuid, _payload jsonb, _cartons jsonb)
 RETURNS SETOF colis
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bl record; v_cmd_id uuid; v_client_nom text;
  v_mode text := _payload->>'mode_acheminement';
  v_responsable text := COALESCE(_payload->>'responsable_nom', auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  v_nb int; v_i int := 0;
  v_carton jsonb; v_ligne jsonb;
  v_colis_id uuid; v_ref text;
  v_designation text; v_prod uuid; v_qte int;
  v_liv uuid;
  v_expected jsonb; v_actual jsonb;
  v_missing text := ''; v_over text := '';
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.assert_permission('colisage.creer');

  IF v_mode NOT IN ('livraison','expedition') THEN
    RAISE EXCEPTION 'Mode d''acheminement invalide (livraison|expedition)';
  END IF;

  SELECT bl.*, c.client_nom AS cnom, bl.commande_id AS cmd
    INTO v_bl
    FROM public.bons_livraison bl
    LEFT JOIN public.commandes c ON c.commande_id = bl.commande_id
    WHERE bl.bl_id = _bl_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de livraison introuvable'; END IF;
  v_cmd_id := v_bl.commande_id;
  v_client_nom := COALESCE(v_bl.cnom, '');

  IF jsonb_typeof(_cartons) <> 'array' OR jsonb_array_length(_cartons) < 1 THEN
    RAISE EXCEPTION 'Au moins un carton est requis';
  END IF;
  v_nb := jsonb_array_length(_cartons);

  IF v_cmd_id IS NOT NULL THEN
    SELECT jsonb_object_agg(produit_id::text, quantite)
      INTO v_expected
      FROM (
        SELECT COALESCE(produit_id, ligne_id) AS produit_id,
               SUM(quantite)::int AS quantite
        FROM public.commande_lignes
        WHERE commande_id = v_cmd_id
        GROUP BY COALESCE(produit_id, ligne_id)
      ) t;

    SELECT jsonb_object_agg(produit_id, quantite)
      INTO v_actual
      FROM (
        SELECT COALESCE((l->>'produit_id'), (l->>'ligne_id')) AS produit_id,
               SUM((l->>'quantite')::int)::int AS quantite
        FROM jsonb_array_elements(_cartons) c,
             jsonb_array_elements(COALESCE(c->'lignes','[]'::jsonb)) l
        GROUP BY COALESCE((l->>'produit_id'), (l->>'ligne_id'))
      ) t;

    v_expected := COALESCE(v_expected, '{}'::jsonb);
    v_actual := COALESCE(v_actual, '{}'::jsonb);

    SELECT string_agg(
             (SELECT designation FROM public.commande_lignes cl
              WHERE COALESCE(cl.produit_id, cl.ligne_id)::text = k
              LIMIT 1)
             || ' (attendu ' || (v_expected->>k) || ', réparti ' || COALESCE(v_actual->>k, '0') || ')',
             ' ; ')
      INTO v_missing
      FROM jsonb_object_keys(v_expected) k
      WHERE COALESCE((v_actual->>k)::int, 0) <> (v_expected->>k)::int;

    SELECT string_agg(k, ', ')
      INTO v_over
      FROM jsonb_object_keys(v_actual) k
      WHERE NOT (v_expected ? k);

    IF v_missing IS NOT NULL AND v_missing <> '' THEN
      RAISE EXCEPTION 'Répartition invalide : %', v_missing;
    END IF;
    IF v_over IS NOT NULL AND v_over <> '' THEN
      RAISE EXCEPTION 'Article(s) non prévu(s) dans la commande : %', v_over;
    END IF;
  END IF;

  DELETE FROM public.colis WHERE bl_id = _bl_id;

  FOR v_i IN 0..(v_nb - 1) LOOP
    v_carton := _cartons -> v_i;
    v_ref := v_bl.reference || '-C' || lpad((v_i + 1)::text, 2, '0');

    INSERT INTO public.colis(
      reference, destinataire, contenu, transporteur, date_envoi, statut,
      bl_id, commande_id, numero_carton, nb_cartons, responsable_id, responsable_nom,
      mode_acheminement, livreur_nom, livreur_telephone, vehicule, quartier, commune,
      ville_livraison, gare_depart, ville_destination, gare_responsable, gare_telephone,
      observations, date_colisage, poids
    ) VALUES (
      v_ref, v_client_nom,
      'Carton ' || (v_i + 1) || '/' || v_nb || ' — BL ' || v_bl.reference,
      CASE WHEN v_mode='expedition' THEN _payload->>'gare_depart' ELSE _payload->>'livreur_nom' END,
      COALESCE((_payload->>'date_colisage')::date, current_date), 'en_preparation',
      _bl_id, v_cmd_id, (v_i + 1), v_nb, auth.uid(), v_responsable,
      v_mode, _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      COALESCE(v_carton->>'observations', _payload->>'observations'),
      COALESCE((_payload->>'date_colisage')::timestamptz, now()),
      COALESCE((v_carton->>'poids')::numeric, 0)
    ) RETURNING colis_id INTO v_colis_id;

    FOR v_ligne IN SELECT jsonb_array_elements(COALESCE(v_carton->'lignes','[]'::jsonb)) LOOP
      v_qte := COALESCE((v_ligne->>'quantite')::int, 0);
      IF v_qte <= 0 THEN
        RAISE EXCEPTION 'Quantité invalide dans le carton %', (v_i + 1);
      END IF;
      v_prod := NULLIF(v_ligne->>'produit_id','')::uuid;
      v_designation := COALESCE(
        v_ligne->>'designation',
        (SELECT designation FROM public.commande_lignes
           WHERE COALESCE(produit_id, ligne_id) = v_prod AND commande_id = v_cmd_id LIMIT 1),
        '—'
      );
      INSERT INTO public.colis_lignes(colis_id, produit_id, designation, reference_produit, quantite, ordre)
      VALUES (
        v_colis_id, v_prod, v_designation,
        v_ligne->>'reference_produit', v_qte,
        COALESCE((v_ligne->>'ordre')::int, 0)
      );
    END LOOP;
  END LOOP;

  UPDATE public.bons_livraison SET statut = 'colisage_termine', updated_at = now() WHERE bl_id = _bl_id;

  IF v_cmd_id IS NOT NULL THEN
    SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = v_cmd_id;
    IF v_liv IS NULL THEN
      PERFORM public.creer_livraison_commande(v_cmd_id);
      SELECT livraison_id INTO v_liv FROM public.livraisons_commande WHERE commande_id = v_cmd_id;
    END IF;
    UPDATE public.livraisons_commande SET
      statut='colisage_termine', bl_id=_bl_id,
      transporteur = COALESCE(_payload->>'livreur_nom', _payload->>'gare_depart'),
      chauffeur_nom = _payload->>'livreur_nom',
      vehicule = _payload->>'vehicule',
      ville_livraison = COALESCE(_payload->>'ville_livraison', _payload->>'ville_destination', ville_livraison),
      nb_cartons = v_nb, derniere_maj = now()
      WHERE livraison_id = v_liv;
    PERFORM public.recalculer_livraison_commande(v_liv);
    INSERT INTO public.livraison_commande_historique(livraison_id, nouveau_statut, commentaire, user_id, user_nom)
    VALUES (v_liv, 'colisage_termine', 'Colisage validé (' || v_nb || ' carton(s))', auth.uid(), v_responsable);
    -- NOTE: création livsuivi_commandes déplacée dans finaliser_tournee.
  END IF;

  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END $function$;

-- 7. Nouvelle RPC de validation de tournée : crée le suivi de livraison
CREATE OR REPLACE FUNCTION public.finaliser_tournee(_tournee_id uuid)
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

  -- Validation des champs obligatoires
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

  -- Création/rafraîchissement d'une ligne livsuivi_commandes par commande distincte
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
      SET tournee_id    = EXCLUDED.tournee_id,
          type_livraison = EXCLUDED.type_livraison,
          statut         = 'preparee'::public.livsuivi_statut,
          bl_id          = EXCLUDED.bl_id,
          nb_cartons     = EXCLUDED.nb_cartons,
          derniere_maj   = now();
  END LOOP;

  -- Passage de la tournée à l'état validé (statut = en_cours)
  UPDATE public.tournees
     SET statut = 'en_cours',
         validation_statut = 'validee',
         validation_at = now()
   WHERE tournee_id = _tournee_id
  RETURNING * INTO v_t;

  RETURN v_t;
END;
$$;

GRANT EXECUTE ON FUNCTION public.finaliser_tournee(uuid) TO authenticated;