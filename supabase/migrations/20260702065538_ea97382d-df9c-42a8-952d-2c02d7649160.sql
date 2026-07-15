
-- 1) Historique des modifications exceptionnelles de colisage
CREATE TABLE public.colisage_modifications_historique (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bl_id uuid NOT NULL REFERENCES public.bons_livraison(bl_id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  user_nom text,
  motif text NOT NULL,
  anciennes_valeurs jsonb NOT NULL DEFAULT '[]'::jsonb,
  nouvelles_valeurs jsonb,
  date_modification timestamptz NOT NULL DEFAULT now(),
  date_revalidation timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_colisage_modif_hist_bl ON public.colisage_modifications_historique(bl_id, date_modification DESC);

GRANT SELECT ON public.colisage_modifications_historique TO authenticated;
GRANT ALL ON public.colisage_modifications_historique TO service_role;

ALTER TABLE public.colisage_modifications_historique ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lecture historique colisage (rôles habilités)"
ON public.colisage_modifications_historique
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'super_admin')
  OR public.has_role(auth.uid(), 'gestionnaire_stock')
  OR public.has_role(auth.uid(), 'responsable_magasinier')
);

-- Aucune policy INSERT/UPDATE/DELETE : accès uniquement via RPC SECURITY DEFINER

-- 2) RPC : déverrouiller un colisage terminé
CREATE OR REPLACE FUNCTION public.deverrouiller_colisage(_bl_id uuid, _motif text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_statut text;
  v_snapshot jsonb;
  v_hist_id uuid;
  v_user_nom text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  IF NOT (
       public.has_role(v_uid, 'super_admin')
    OR public.has_role(v_uid, 'gestionnaire_stock')
    OR public.has_role(v_uid, 'responsable_magasinier')
  ) THEN
    RAISE EXCEPTION 'Accès refusé : seuls le Gestionnaire de Stock et le Responsable Magasinier peuvent déverrouiller un colisage';
  END IF;

  IF _motif IS NULL OR btrim(_motif) = '' THEN
    RAISE EXCEPTION 'Le motif de modification est obligatoire';
  END IF;

  SELECT statut INTO v_statut FROM public.bons_livraison WHERE bl_id = _bl_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bon de livraison introuvable';
  END IF;
  IF v_statut <> 'colisage_termine' THEN
    RAISE EXCEPTION 'Seul un colisage à l''état « terminé » peut être déverrouillé (statut actuel : %)', v_statut;
  END IF;

  -- Snapshot des colis existants
  SELECT COALESCE(jsonb_agg(to_jsonb(c.*) ORDER BY c.numero_carton), '[]'::jsonb)
    INTO v_snapshot
  FROM public.colis c
  WHERE c.bl_id = _bl_id;

  v_user_nom := COALESCE(
    auth.jwt()->'user_metadata'->>'nom_complet',
    auth.jwt()->>'email'
  );

  INSERT INTO public.colisage_modifications_historique(
    bl_id, user_id, user_nom, motif, anciennes_valeurs
  )
  VALUES (_bl_id, v_uid, v_user_nom, btrim(_motif), v_snapshot)
  RETURNING id INTO v_hist_id;

  UPDATE public.bons_livraison
     SET statut = 'colisage_en_cours', updated_at = now()
   WHERE bl_id = _bl_id;

  RETURN v_hist_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.deverrouiller_colisage(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deverrouiller_colisage(uuid, text) TO authenticated, service_role;

-- 3) Mise à jour de creer_colisage pour clôturer la dernière ligne d'historique ouverte
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
  v_livsuivi_id uuid; v_livsuivi_type text;
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

    v_livsuivi_type := CASE WHEN v_mode='expedition' THEN 'expedition' ELSE 'direct' END;
    SELECT id INTO v_livsuivi_id FROM public.livsuivi_commandes WHERE commande_id = v_bl.commande_id;
    IF v_livsuivi_id IS NULL THEN
      INSERT INTO public.livsuivi_commandes(commande_id, type_livraison, statut, bl_id, nb_cartons, derniere_maj)
      VALUES (v_bl.commande_id, v_livsuivi_type, 'colisage_termine', _bl_id, v_nb, now())
      RETURNING id INTO v_livsuivi_id;
    ELSE
      UPDATE public.livsuivi_commandes SET
        type_livraison = v_livsuivi_type, statut='colisage_termine',
        bl_id=_bl_id, nb_cartons=v_nb, derniere_maj=now()
        WHERE id = v_livsuivi_id;
    END IF;
  END IF;

  -- Clôture de la dernière ligne d'historique de modification restée ouverte
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
