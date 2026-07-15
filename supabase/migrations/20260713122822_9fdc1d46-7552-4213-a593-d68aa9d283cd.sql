-- Correctif : autorisations du module Suivi des livraisons
-- ------------------------------------------------------------
-- Avant : `livsuivi_confirmer_reception` réclamait la permission
-- inexistante `livsuivi.avancer` → toute confirmation de réception
-- (dernière étape après clôture d'une tournée) échouait avec
-- « Permission refusée ». Les RPC `livsuivi_avancer` et
-- `livsuivi_avancer_masse` s'appuyaient sur une liste de rôles figée
-- (`super_admin`, `directeur_general`, `service_logistique`), ignorant
-- les rôles RBAC v2 (responsable_magasinier, responsable_logistique…)
-- pourtant habilités à faire avancer les livraisons.
-- Après : toutes les RPC utilisent les permissions officielles du
-- catalogue (`livraisons.avancer_etape`, `livraisons.avancer_masse`).

CREATE OR REPLACE FUNCTION public.livsuivi_avancer(
  _livraison_id uuid,
  _etape livsuivi_statut,
  _meta jsonb DEFAULT '{}'::jsonb,
  _commentaire text DEFAULT NULL::text
)
RETURNS livsuivi_commandes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_liv public.livsuivi_commandes;
  v_next public.livsuivi_statut;
  v_user text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  PERFORM public.assert_permission('livraisons.avancer_etape');

  SELECT * INTO v_liv FROM public.livsuivi_commandes WHERE id = _livraison_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Livraison introuvable'; END IF;

  v_next := public.livsuivi_next_etape(v_liv.type_livraison, v_liv.statut);
  IF v_liv.type_livraison = 'expedition' AND v_liv.statut = 'arrivee_gare' AND _etape = 'livree_locale' THEN
    v_next := 'livree_locale';
  END IF;
  IF v_next IS NULL OR _etape <> v_next THEN
    RAISE EXCEPTION 'Transition non autorisée: % -> %', v_liv.statut, _etape;
  END IF;

  v_user := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  UPDATE public.livsuivi_commandes SET
    statut = _etape,
    livreur_nom = COALESCE(_meta->>'livreur_nom', livreur_nom),
    vehicule = COALESCE(_meta->>'vehicule', vehicule),
    gare_destination = COALESCE(_meta->>'gare_destination', gare_destination),
    ville_destination = COALESCE(_meta->>'ville_destination', ville_destination),
    receptionnaire_nom = COALESCE(_meta->>'receptionnaire_nom', receptionnaire_nom),
    cloturee = (_etape IN ('livree','retiree_client','livree_locale')),
    derniere_maj = now()
  WHERE id = _livraison_id
  RETURNING * INTO v_liv;

  INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, meta, user_id, user_nom)
  VALUES (_livraison_id, _etape, _commentaire, COALESCE(_meta, '{}'::jsonb), auth.uid(), v_user);

  RETURN v_liv;
END
$function$;

CREATE OR REPLACE FUNCTION public.livsuivi_avancer_masse(
  _tournee_id uuid,
  _etape livsuivi_statut,
  _meta jsonb DEFAULT '{}'::jsonb,
  _filtre_gare text DEFAULT NULL::text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row record;
  v_count int := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  PERFORM public.assert_permission('livraisons.avancer_masse');

  FOR v_row IN
    SELECT id FROM public.livsuivi_commandes
     WHERE tournee_id = _tournee_id
       AND (_filtre_gare IS NULL OR gare_destination = _filtre_gare)
       AND public.livsuivi_next_etape(type_livraison, statut) = _etape
  LOOP
    PERFORM public.livsuivi_avancer(v_row.id, _etape, _meta, 'Action groupée tournée');
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END
$function$;

CREATE OR REPLACE FUNCTION public.livsuivi_confirmer_reception(
  _id uuid,
  _signature_url text DEFAULT NULL::text,
  _photo_url text DEFAULT NULL::text,
  _receptionnaire_nom text DEFAULT NULL::text,
  _receptionnaire_tel text DEFAULT NULL::text,
  _commentaire text DEFAULT NULL::text
)
RETURNS livsuivi_commandes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row public.livsuivi_commandes;
  v_user text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  PERFORM public.assert_permission('livraisons.avancer_etape');

  SELECT COALESCE(nom_complet, email, auth.uid()::text) INTO v_user
    FROM public.profiles WHERE user_id = auth.uid();

  UPDATE public.livsuivi_commandes
     SET statut = 'reception_confirmee'::public.livsuivi_statut,
         signature_url = COALESCE(_signature_url, signature_url),
         photo_preuve_url = COALESCE(_photo_url, photo_preuve_url),
         receptionnaire_nom = COALESCE(_receptionnaire_nom, receptionnaire_nom),
         receptionnaire_telephone = COALESCE(_receptionnaire_tel, receptionnaire_telephone),
         commentaire_reception = COALESCE(_commentaire, commentaire_reception),
         heure_livraison = COALESCE(heure_livraison, now()),
         derniere_maj = now(),
         cloturee = true
   WHERE id = _id
  RETURNING * INTO v_row;
  IF NOT FOUND THEN RAISE EXCEPTION 'Livraison introuvable'; END IF;

  INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, meta, user_id, user_nom)
  VALUES (
    _id,
    'reception_confirmee'::public.livsuivi_statut,
    _commentaire,
    jsonb_strip_nulls(jsonb_build_object(
      'signature_url', _signature_url,
      'photo_preuve_url', _photo_url,
      'receptionnaire_nom', _receptionnaire_nom,
      'receptionnaire_telephone', _receptionnaire_tel
    )),
    auth.uid(),
    v_user
  );

  RETURN v_row;
END
$function$;