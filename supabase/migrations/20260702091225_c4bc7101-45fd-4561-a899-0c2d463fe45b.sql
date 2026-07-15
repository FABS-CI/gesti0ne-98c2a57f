
-- 1) Table colis_lignes ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.colis_lignes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  colis_id uuid NOT NULL REFERENCES public.colis(colis_id) ON DELETE CASCADE,
  produit_id uuid REFERENCES public.produits(produit_id) ON DELETE SET NULL,
  designation text NOT NULL,
  reference_produit text,
  quantite integer NOT NULL CHECK (quantite > 0),
  poids numeric,
  ordre integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS colis_lignes_colis_idx ON public.colis_lignes(colis_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.colis_lignes TO authenticated;
GRANT ALL ON public.colis_lignes TO service_role;

ALTER TABLE public.colis_lignes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff read colis_lignes" ON public.colis_lignes;
CREATE POLICY "staff read colis_lignes" ON public.colis_lignes
  FOR SELECT TO authenticated USING (is_staff(auth.uid()));

DROP POLICY IF EXISTS "staff write colis_lignes" ON public.colis_lignes;
CREATE POLICY "staff write colis_lignes" ON public.colis_lignes
  FOR ALL TO authenticated USING (is_staff(auth.uid())) WITH CHECK (is_staff(auth.uid()));

DROP TRIGGER IF EXISTS update_colis_lignes_updated_at ON public.colis_lignes;
CREATE TRIGGER update_colis_lignes_updated_at
  BEFORE UPDATE ON public.colis_lignes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2) RPC creer_colisage_manuel --------------------------------------------------
CREATE OR REPLACE FUNCTION public.creer_colisage_manuel(
  _bl_id uuid,
  _payload jsonb,
  _cartons jsonb
) RETURNS SETOF public.colis
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_bl record; v_cmd_id uuid; v_client_nom text;
  v_mode text := _payload->>'mode_acheminement';
  v_responsable text := COALESCE(_payload->>'responsable_nom', auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  v_nb int; v_i int := 0;
  v_carton jsonb; v_ligne jsonb;
  v_colis_id uuid; v_ref text;
  v_designation text; v_prod uuid; v_qte int;
  v_liv uuid; v_livsuivi_id uuid; v_livsuivi_type text;
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

  -- Validation : totaux par produit ------------------------------------------
  IF v_cmd_id IS NOT NULL THEN
    -- Totaux attendus (commande)
    SELECT jsonb_object_agg(produit_id::text, quantite)
      INTO v_expected
      FROM (
        SELECT COALESCE(produit_id, ligne_id) AS produit_id,
               SUM(quantite)::int AS quantite
        FROM public.commande_lignes
        WHERE commande_id = v_cmd_id
        GROUP BY COALESCE(produit_id, ligne_id)
      ) t;

    -- Totaux répartis (payload)
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

    -- Chercher écarts
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

  -- Purge ancienne composition ------------------------------------------------
  DELETE FROM public.colis WHERE bl_id = _bl_id;

  -- Création cartons + lignes ------------------------------------------------
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

    -- Lignes du carton
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

  -- Livraisons commande + suivi (identique à creer_colisage) -----------------
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

    v_livsuivi_type := CASE WHEN v_mode='expedition' THEN 'expedition' ELSE 'direct' END;
    SELECT id INTO v_livsuivi_id FROM public.livsuivi_commandes WHERE commande_id = v_cmd_id;
    IF v_livsuivi_id IS NULL THEN
      INSERT INTO public.livsuivi_commandes(commande_id, type_livraison, statut, bl_id, nb_cartons, derniere_maj)
      VALUES (v_cmd_id, v_livsuivi_type::public.livsuivi_type, 'preparee'::public.livsuivi_statut, _bl_id, v_nb, now());
    ELSE
      UPDATE public.livsuivi_commandes SET
        type_livraison = v_livsuivi_type::public.livsuivi_type,
        statut = 'preparee'::public.livsuivi_statut,
        bl_id = _bl_id, nb_cartons = v_nb, derniere_maj = now()
        WHERE id = v_livsuivi_id;
    END IF;
  END IF;

  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END $$;

GRANT EXECUTE ON FUNCTION public.creer_colisage_manuel(uuid, jsonb, jsonb) TO authenticated;

-- 3) RPC modifier_colis_lignes -------------------------------------------------
CREATE OR REPLACE FUNCTION public.modifier_colis_lignes(
  _colis_id uuid,
  _lignes jsonb,
  _motif text DEFAULT ''
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_bl uuid; v_ancien jsonb; v_nouveau jsonb;
  v_ligne jsonb; v_qte int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  SELECT bl_id INTO v_bl FROM public.colis WHERE colis_id = _colis_id;
  IF v_bl IS NULL THEN RAISE EXCEPTION 'Carton introuvable'; END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'produit_id', produit_id, 'designation', designation, 'quantite', quantite
  )), '[]'::jsonb) INTO v_ancien
  FROM public.colis_lignes WHERE colis_id = _colis_id;

  DELETE FROM public.colis_lignes WHERE colis_id = _colis_id;

  FOR v_ligne IN SELECT jsonb_array_elements(COALESCE(_lignes,'[]'::jsonb)) LOOP
    v_qte := COALESCE((v_ligne->>'quantite')::int, 0);
    IF v_qte <= 0 THEN RAISE EXCEPTION 'Quantité invalide'; END IF;
    INSERT INTO public.colis_lignes(colis_id, produit_id, designation, reference_produit, quantite, ordre)
    VALUES (
      _colis_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      COALESCE(v_ligne->>'designation','—'),
      v_ligne->>'reference_produit',
      v_qte,
      COALESCE((v_ligne->>'ordre')::int, 0)
    );
  END LOOP;

  v_nouveau := _lignes;

  INSERT INTO public.colisage_modifications_historique(
    bl_id, user_id, user_nom, motif, anciennes_valeurs, nouvelles_valeurs
  ) VALUES (
    v_bl, auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email'),
    COALESCE(NULLIF(_motif,''), 'Modification contenu carton'),
    v_ancien, v_nouveau
  );
END $$;

GRANT EXECUTE ON FUNCTION public.modifier_colis_lignes(uuid, jsonb, text) TO authenticated;

-- 4) get_carton_public : préférer colis_lignes ---------------------------------
CREATE OR REPLACE FUNCTION public.get_carton_public(_colis_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_colis record; v_bl record; v_cmd record;
  v_lignes jsonb; v_has_manual boolean;
BEGIN
  SELECT * INTO v_colis FROM public.colis WHERE colis_id = _colis_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  SELECT bl_id, reference, statut, date_emission INTO v_bl
    FROM public.bons_livraison WHERE bl_id = v_colis.bl_id;

  SELECT commande_id, reference, client_nom, etablissement, representant_nom,
         telephone, ville, adresse
    INTO v_cmd
    FROM public.commandes WHERE commande_id = v_colis.commande_id;

  SELECT EXISTS(SELECT 1 FROM public.colis_lignes WHERE colis_id = _colis_id) INTO v_has_manual;

  IF v_has_manual THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'designation', designation,
             'quantite', quantite
           ) ORDER BY ordre, designation), '[]'::jsonb)
      INTO v_lignes
      FROM public.colis_lignes
      WHERE colis_id = _colis_id;
  ELSE
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'designation', l.designation,
             'quantite', l.quantite
           ) ORDER BY l.designation), '[]'::jsonb)
      INTO v_lignes
      FROM public.commande_lignes l
      WHERE l.commande_id = v_colis.commande_id;
  END IF;

  RETURN jsonb_build_object(
    'colis_id', v_colis.colis_id,
    'reference_colis', v_colis.reference,
    'numero_carton', v_colis.numero_carton,
    'nb_cartons', v_colis.nb_cartons,
    'bl_reference', v_bl.reference,
    'bl_statut', v_bl.statut,
    'commande_reference', v_cmd.reference,
    'client_nom', v_cmd.client_nom,
    'etablissement', v_cmd.etablissement,
    'destinataire', COALESCE(v_cmd.representant_nom, v_colis.destinataire),
    'telephone', v_cmd.telephone,
    'adresse', v_cmd.adresse,
    'ville', v_cmd.ville,
    'destination', COALESCE(v_colis.ville_destination, v_colis.ville_livraison, v_cmd.ville),
    'mode_acheminement', v_colis.mode_acheminement,
    'statut_logistique', COALESCE(v_colis.statut_logistique, v_colis.statut),
    'date_colisage', v_colis.date_colisage,
    'preparateur', v_colis.responsable_nom,
    'observations', v_colis.observations,
    'poids', v_colis.poids,
    'produits', v_lignes
  );
END $$;
