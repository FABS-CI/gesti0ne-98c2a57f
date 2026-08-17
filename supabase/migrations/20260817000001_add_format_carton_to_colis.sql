ALTER TABLE public.colis ADD COLUMN IF NOT EXISTS format_carton text;

CREATE OR REPLACE FUNCTION public.creer_colisage_manuel(
  _bl_id uuid,
  _payload jsonb,
  _cartons jsonb
)
RETURNS SETOF public.colis
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_colis_id uuid;
  v_carton jsonb;
  v_ligne jsonb;
  v_now timestamptz := now();
BEGIN
  -- 1. Nettoyage
  DELETE FROM public.colis_lignes WHERE colis_id IN (SELECT colis_id FROM public.colis WHERE bl_id = _bl_id);
  DELETE FROM public.colis WHERE bl_id = _bl_id;

  -- 2. Mise à jour du BL
  UPDATE public.bons_livraison
  SET 
    statut = 'colisage_termine',
    date_colisage = v_now
  WHERE bl_id = _bl_id;

  -- 3. Création des cartons
  FOR v_carton IN SELECT * FROM jsonb_array_elements(_cartons)
  LOOP
    INSERT INTO public.colis (
      bl_id,
      numero_carton,
      nb_cartons,
      poids,
      observations,
      responsable_nom,
      mode_acheminement,
      quartier,
      commune,
      ville_livraison,
      gare_depart,
      ville_destination,
      gare_responsable,
      gare_telephone,
      format_carton, -- Nouveau champ
      date_colisage
    ) VALUES (
      _bl_id,
      (v_carton->>'numero')::int,
      (_payload->>'nb_cartons')::int,
      (v_carton->>'poids')::numeric,
      v_carton->>'observations',
      _payload->>'responsable_nom',
      _payload->>'mode_acheminement',
      _payload->>'quartier',
      _payload->>'commune',
      _payload->>'ville_livraison',
      _payload->>'gare_depart',
      _payload->>'ville_destination',
      _payload->>'gare_responsable',
      _payload->>'gare_telephone',
      v_carton->>'format', -- Mappage du champ JSON 'format'
      v_now
    ) RETURNING colis_id INTO v_colis_id;

    -- 4. Insertion des lignes
    FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_carton->'lignes')
    LOOP
      INSERT INTO public.colis_lignes (
        colis_id,
        produit_id,
        designation,
        reference_produit,
        quantite
      ) VALUES (
        v_colis_id,
        (v_ligne->>'produit_id')::uuid,
        v_ligne->>'designation',
        v_ligne->>'reference_produit',
        (v_ligne->>'quantite')::int
      );
    END LOOP;
  END LOOP;

  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton ASC;
END;
$$;
