CREATE OR REPLACE FUNCTION public.creer_colisage_manuel(_bl_id uuid, _payload jsonb, _cartons jsonb)
 RETURNS SETOF colis
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_carton jsonb;
  v_ligne jsonb;
  v_colis_id uuid;
  v_ref text;
  v_bl_ref text;
  v_num integer := 0;
  v_nb integer := jsonb_array_length(_cartons);
BEGIN
  PERFORM public.assert_permission('colisage.creer');

  -- Suppression des anciens colis (cascade sur lignes via FK)
  DELETE FROM public.colis WHERE bl_id = _bl_id;
  
  SELECT reference INTO v_bl_ref FROM public.bons_livraison WHERE bl_id = _bl_id;

  FOR v_carton IN SELECT * FROM jsonb_array_elements(_cartons) LOOP
    v_num := v_num + 1;
    -- Ajout d'un suffixe aléatoire pour garantir l'unicité des références en cas de recréation rapide
    v_ref := COALESCE(v_bl_ref, 'BL') || '-C' || lpad(v_num::text, 3, '0') || '-' || substring(md5(random()::text), 1, 6);
    
    INSERT INTO public.colis(
      bl_id, reference, numero_carton, nb_cartons,
      responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule,
      quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone,
      poids, observations, date_colisage
    ) VALUES (
      _bl_id, v_ref, v_num, v_nb,
      _payload->>'responsable_nom', _payload->>'mode_acheminement',
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      COALESCE((v_carton->>'poids')::numeric, 0),
      COALESCE(v_carton->>'observations', _payload->>'observations'),
      COALESCE((_payload->>'date_colisage')::timestamptz, now())
    ) RETURNING colis_id INTO v_colis_id;

    FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_carton->'lignes') LOOP
      -- Utilisation explicite d'un UUID pour éviter les conflits de clé primaire
      INSERT INTO public.colis_lignes(ligne_id, colis_id, produit_id, designation, reference_produit, quantite)
      VALUES (
        gen_random_uuid(),
        v_colis_id,
        NULLIF(v_ligne->>'produit_id','')::uuid,
        v_ligne->>'designation',
        v_ligne->>'reference_produit',
        COALESCE((v_ligne->>'quantite')::numeric, 0)
      );
    END LOOP;
  END LOOP;

  UPDATE public.bons_livraison SET statut = 'colisage_termine' WHERE bl_id = _bl_id;
  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END;
$function$;