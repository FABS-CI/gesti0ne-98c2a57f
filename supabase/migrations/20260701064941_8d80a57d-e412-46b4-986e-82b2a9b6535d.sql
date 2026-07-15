
-- Helper: valider transition de statut
CREATE OR REPLACE FUNCTION public.valider_transition_livraison(
  _ancien public.statut_livraison_cmd,
  _nouveau public.statut_livraison_cmd,
  _type public.type_livraison
) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE
SET search_path = public
AS $$
DECLARE
  allowed text[];
BEGIN
  -- Retour et annulation toujours possibles depuis un statut actif
  IF _nouveau IN ('retour','annulee') AND _ancien NOT IN ('livree','retiree_client','annulee') THEN
    RETURN true;
  END IF;

  IF _type = 'directe' THEN
    allowed := CASE _ancien::text
      WHEN 'en_attente' THEN ARRAY['assignee']
      WHEN 'assignee' THEN ARRAY['chargee','en_route']
      WHEN 'chargee' THEN ARRAY['en_route']
      WHEN 'en_route' THEN ARRAY['livree']
      ELSE ARRAY[]::text[]
    END;
  ELSIF _type = 'expedition' THEN
    allowed := CASE _ancien::text
      WHEN 'en_attente' THEN ARRAY['assignee']
      WHEN 'assignee' THEN ARRAY['chargee']
      WHEN 'chargee' THEN ARRAY['en_route']
      WHEN 'en_route' THEN ARRAY['deposee_gare']
      WHEN 'deposee_gare' THEN ARRAY['arrivee_destination']
      WHEN 'arrivee_destination' THEN ARRAY['retiree_client']
      ELSE ARRAY[]::text[]
    END;
  ELSE
    -- Type non défini: transitions minimales
    allowed := ARRAY['assignee'];
  END IF;

  RETURN _nouveau::text = ANY(allowed);
END;
$$;

-- RPC: Assigner des livraisons à une tournée
CREATE OR REPLACE FUNCTION public.assigner_livraisons_tournee(
  p_tournee_id uuid,
  p_livreur_id uuid,
  p_assignments jsonb
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role_ok boolean;
  v_user uuid := auth.uid();
  v_user_nom text;
  v_item jsonb;
  v_liv_id uuid;
  v_type public.type_livraison;
  v_gare text;
  v_ancien public.statut_livraison_cmd;
  v_count integer := 0;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  SELECT (
    public.has_role(v_user,'super_admin') OR
    public.has_role(v_user,'DG') OR
    public.has_role(v_user,'service_logistique') OR
    public.has_role(v_user,'directeur_commercial') OR
    public.has_role(v_user,'responsable_magasinier') OR
    public.has_role(v_user,'gestionnaire_stock')
  ) INTO v_role_ok;

  IF NOT v_role_ok THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT COALESCE(nom_complet, email) INTO v_user_nom
  FROM public.profiles WHERE id = v_user;

  -- Mettre à jour le livreur de la tournée si fourni
  IF p_livreur_id IS NOT NULL THEN
    UPDATE public.tournees SET livreur_id = p_livreur_id WHERE id = p_tournee_id;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_assignments)
  LOOP
    v_liv_id := (v_item->>'livraison_id')::uuid;
    v_type := (v_item->>'type_livraison')::public.type_livraison;
    v_gare := v_item->>'gare_nom';

    SELECT statut INTO v_ancien FROM public.livraisons_commande WHERE id = v_liv_id FOR UPDATE;
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    UPDATE public.livraisons_commande
       SET tournee_id = p_tournee_id,
           livreur_id = COALESCE(p_livreur_id, livreur_id),
           type_livraison = v_type,
           gare_nom = CASE WHEN v_type='expedition' THEN v_gare ELSE NULL END,
           statut = 'assignee',
           derniere_maj = now(),
           updated_at = now()
     WHERE id = v_liv_id;

    INSERT INTO public.livraison_commande_historique(
      livraison_id, ancien_statut, nouveau_statut, commentaire, user_id, user_nom
    ) VALUES (
      v_liv_id, v_ancien, 'assignee',
      'Assignation à la tournée', v_user, v_user_nom
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- RPC: Changer le statut d'une livraison
CREATE OR REPLACE FUNCTION public.changer_statut_livraison(
  p_livraison_id uuid,
  p_nouveau_statut public.statut_livraison_cmd,
  p_commentaire text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_user_nom text;
  v_ancien public.statut_livraison_cmd;
  v_type public.type_livraison;
  v_role_ok boolean;
  v_hist_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  SELECT (
    public.has_role(v_user,'super_admin') OR
    public.has_role(v_user,'DG') OR
    public.has_role(v_user,'service_logistique') OR
    public.has_role(v_user,'directeur_commercial') OR
    public.has_role(v_user,'responsable_magasinier') OR
    public.has_role(v_user,'gestionnaire_stock')
  ) INTO v_role_ok;

  IF NOT v_role_ok THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT statut, type_livraison INTO v_ancien, v_type
  FROM public.livraisons_commande
  WHERE id = p_livraison_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Livraison introuvable';
  END IF;

  IF NOT public.valider_transition_livraison(v_ancien, p_nouveau_statut, v_type) THEN
    RAISE EXCEPTION 'Transition non autorisée: % -> % (type=%)', v_ancien, p_nouveau_statut, v_type;
  END IF;

  SELECT COALESCE(nom_complet, email) INTO v_user_nom
  FROM public.profiles WHERE id = v_user;

  UPDATE public.livraisons_commande
     SET statut = p_nouveau_statut,
         heure_depart = CASE WHEN p_nouveau_statut = 'en_route' AND heure_depart IS NULL THEN now() ELSE heure_depart END,
         date_expedition = CASE WHEN p_nouveau_statut IN ('en_route','deposee_gare') AND date_expedition IS NULL THEN now() ELSE date_expedition END,
         date_livraison = CASE WHEN p_nouveau_statut IN ('livree','retiree_client') THEN now() ELSE date_livraison END,
         derniere_maj = now(),
         updated_at = now()
   WHERE id = p_livraison_id;

  INSERT INTO public.livraison_commande_historique(
    livraison_id, ancien_statut, nouveau_statut, commentaire, user_id, user_nom
  ) VALUES (
    p_livraison_id, v_ancien, p_nouveau_statut, p_commentaire, v_user, v_user_nom
  ) RETURNING id INTO v_hist_id;

  RETURN v_hist_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assigner_livraisons_tournee(uuid, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.changer_statut_livraison(uuid, public.statut_livraison_cmd, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.valider_transition_livraison(public.statut_livraison_cmd, public.statut_livraison_cmd, public.type_livraison) TO authenticated;
