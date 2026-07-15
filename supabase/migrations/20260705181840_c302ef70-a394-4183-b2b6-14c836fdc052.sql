CREATE OR REPLACE FUNCTION public.livsuivi_creer_tournee(_payload jsonb)
 RETURNS livsuivi_tournees
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_t public.livsuivi_tournees; v_ids uuid[]; v_user text; v_type public.livsuivi_type;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  v_user := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  v_type := (_payload->>'type')::public.livsuivi_type;
  INSERT INTO public.livsuivi_tournees(type, livreur_nom, livreur_contact, vehicule, date_depart, observations, created_by, created_by_nom)
  VALUES (v_type, _payload->>'livreur_nom', _payload->>'livreur_contact',
    _payload->>'vehicule', COALESCE((_payload->>'date_depart')::date, current_date),
    _payload->>'observations', auth.uid(), v_user) RETURNING * INTO v_t;
  IF _payload ? 'commande_ids' THEN
    SELECT ARRAY(SELECT jsonb_array_elements_text(_payload->'commande_ids'))::uuid[] INTO v_ids;
    IF v_type = 'mixte' THEN
      -- Conserver le type_livraison propre à chaque commande
      UPDATE public.livsuivi_commandes SET tournee_id = v_t.id
        WHERE id = ANY(v_ids) AND statut = 'preparee';
    ELSE
      UPDATE public.livsuivi_commandes SET tournee_id = v_t.id, type_livraison = v_t.type
        WHERE id = ANY(v_ids) AND statut = 'preparee';
    END IF;
  END IF;
  RETURN v_t;
END $function$;