
-- ============================================================
-- 1. Complète creer_colisage : seed livsuivi_commandes + audit
-- ============================================================
CREATE OR REPLACE FUNCTION public.creer_colisage(_bl_id uuid, _payload jsonb)
RETURNS SETOF public.colis
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_bl record; v_nb int := GREATEST(COALESCE((_payload->>'nb_cartons')::int, 1), 1);
  v_mode text := _payload->>'mode_acheminement';
  v_responsable text := COALESCE(_payload->>'responsable_nom', auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  v_client_nom text; i int; v_ref text; v_liv uuid;
  v_livsuivi_id uuid; v_livsuivi_type text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
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

  -- livraisons_commande (module existant)
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

    -- ✨ Déclenche automatiquement le module Suivi de livraison
    v_livsuivi_type := CASE WHEN v_mode='expedition' THEN 'expedition' ELSE 'direct' END;
    SELECT id INTO v_livsuivi_id FROM public.livsuivi_commandes WHERE commande_id = v_bl.commande_id;
    IF v_livsuivi_id IS NULL THEN
      INSERT INTO public.livsuivi_commandes(commande_id, type_livraison, statut,
        gare_depot, ville_destination, livreur_nom, vehicule, derniere_maj)
      VALUES (v_bl.commande_id, v_livsuivi_type::livsuivi_type, 'preparee'::livsuivi_statut,
        _payload->>'gare_depart',
        COALESCE(_payload->>'ville_destination', _payload->>'ville_livraison'),
        _payload->>'livreur_nom', _payload->>'vehicule', now())
      RETURNING id INTO v_livsuivi_id;
    ELSE
      UPDATE public.livsuivi_commandes SET
        type_livraison = v_livsuivi_type::livsuivi_type,
        statut = CASE WHEN cloturee THEN statut ELSE 'preparee'::livsuivi_statut END,
        gare_depot = COALESCE(_payload->>'gare_depart', gare_depot),
        ville_destination = COALESCE(_payload->>'ville_destination', _payload->>'ville_livraison', ville_destination),
        livreur_nom = COALESCE(_payload->>'livreur_nom', livreur_nom),
        vehicule = COALESCE(_payload->>'vehicule', vehicule),
        derniere_maj = now()
      WHERE id = v_livsuivi_id;
    END IF;

    INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, meta, user_nom)
    VALUES (v_livsuivi_id, 'preparee'::livsuivi_statut,
      'Colisage validé ('||v_nb||' carton(s)) — suivi de livraison déclenché',
      jsonb_build_object('bl_id', _bl_id, 'nb_cartons', v_nb, 'mode', v_mode),
      v_responsable);
  END IF;

  -- Audit
  INSERT INTO public.audit_logs(action, ressource, ressource_id, details, user_id)
  VALUES ('colisage_termine', 'bons_livraison', _bl_id,
    jsonb_build_object('nb_cartons', v_nb, 'mode', v_mode, 'livsuivi_id', v_livsuivi_id),
    auth.uid());

  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END $function$;

-- ============================================================
-- 2. Vue publique carton (QR Code) — SANS AUTHENTIFICATION
--    Ne renvoie que les données logistiques ; aucun prix / marge / coût.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_carton_public(_colis_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_colis record; v_bl record; v_cmd record; v_lignes jsonb;
BEGIN
  SELECT * INTO v_colis FROM public.colis WHERE colis_id = _colis_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  SELECT bl_id, reference, statut, date_emission INTO v_bl
    FROM public.bons_livraison WHERE bl_id = v_colis.bl_id;

  SELECT commande_id, reference, client_nom, etablissement, representant_nom,
         telephone, ville, adresse
    INTO v_cmd
    FROM public.commandes WHERE commande_id = v_colis.commande_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'designation', l.designation,
           'quantite', l.quantite
         ) ORDER BY l.designation), '[]'::jsonb)
    INTO v_lignes
    FROM public.commande_lignes l
    WHERE l.commande_id = v_colis.commande_id;

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
    'produits', v_lignes
  );
END $$;

REVOKE ALL ON FUNCTION public.get_carton_public(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_carton_public(uuid) TO anon, authenticated;

COMMENT ON FUNCTION public.get_carton_public(uuid) IS
  'Consultation publique d''un carton via QR code. N''expose aucune donnée financière.';
