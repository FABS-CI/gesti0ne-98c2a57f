
ALTER TABLE public.colis
  ADD COLUMN IF NOT EXISTS bl_id uuid REFERENCES public.bons_livraison(bl_id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS commande_id uuid REFERENCES public.commandes(commande_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS numero_carton integer,
  ADD COLUMN IF NOT EXISTS nb_cartons integer,
  ADD COLUMN IF NOT EXISTS responsable_id uuid,
  ADD COLUMN IF NOT EXISTS responsable_nom text,
  ADD COLUMN IF NOT EXISTS mode_acheminement text,
  ADD COLUMN IF NOT EXISTS livreur_nom text,
  ADD COLUMN IF NOT EXISTS livreur_telephone text,
  ADD COLUMN IF NOT EXISTS vehicule text,
  ADD COLUMN IF NOT EXISTS quartier text,
  ADD COLUMN IF NOT EXISTS commune text,
  ADD COLUMN IF NOT EXISTS ville_livraison text,
  ADD COLUMN IF NOT EXISTS gare_depart text,
  ADD COLUMN IF NOT EXISTS ville_destination text,
  ADD COLUMN IF NOT EXISTS gare_responsable text,
  ADD COLUMN IF NOT EXISTS gare_telephone text,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS date_colisage timestamptz;

CREATE INDEX IF NOT EXISTS colis_bl_id_idx ON public.colis(bl_id);

UPDATE public.bons_livraison SET statut = 'a_preparer' WHERE statut = 'brouillon';

CREATE OR REPLACE FUNCTION public.creer_colisage(_bl_id uuid, _payload jsonb)
RETURNS SETOF public.colis
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bl record;
  v_nb int := GREATEST(COALESCE((_payload->>'nb_cartons')::int, 1), 1);
  v_mode text := _payload->>'mode_acheminement';
  v_responsable text := COALESCE(_payload->>'responsable_nom', auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');
  v_client_nom text;
  i int;
  v_ref text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF v_mode NOT IN ('livraison','expedition') THEN
    RAISE EXCEPTION 'Mode d''acheminement invalide (livraison|expedition)';
  END IF;

  SELECT bl.*, c.client_nom AS cnom
    INTO v_bl
    FROM public.bons_livraison bl
    LEFT JOIN public.commandes c ON c.commande_id = bl.commande_id
   WHERE bl.bl_id = _bl_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de livraison introuvable'; END IF;

  v_client_nom := COALESCE(v_bl.cnom, '');

  -- Supprime un éventuel colisage précédent pour ce BL
  DELETE FROM public.colis WHERE bl_id = _bl_id;

  FOR i IN 1..v_nb LOOP
    v_ref := v_bl.reference || '-C' || lpad(i::text, 2, '0');
    INSERT INTO public.colis(
      reference, destinataire, contenu, transporteur, date_envoi, statut,
      bl_id, commande_id, numero_carton, nb_cartons,
      responsable_id, responsable_nom, mode_acheminement,
      livreur_nom, livreur_telephone, vehicule, quartier, commune, ville_livraison,
      gare_depart, ville_destination, gare_responsable, gare_telephone,
      observations, date_colisage
    ) VALUES (
      v_ref, v_client_nom,
      'Carton '||i||'/'||v_nb||' — BL '||v_bl.reference,
      CASE WHEN v_mode='expedition' THEN _payload->>'gare_depart' ELSE _payload->>'livreur_nom' END,
      COALESCE((_payload->>'date_colisage')::date, current_date),
      'en_preparation',
      _bl_id, v_bl.commande_id, i, v_nb,
      auth.uid(), v_responsable, v_mode,
      _payload->>'livreur_nom', _payload->>'livreur_telephone', _payload->>'vehicule',
      _payload->>'quartier', _payload->>'commune', _payload->>'ville_livraison',
      _payload->>'gare_depart', _payload->>'ville_destination',
      _payload->>'gare_responsable', _payload->>'gare_telephone',
      _payload->>'observations', COALESCE((_payload->>'date_colisage')::timestamptz, now())
    );
  END LOOP;

  UPDATE public.bons_livraison
     SET statut = 'colisage_termine', updated_at = now()
   WHERE bl_id = _bl_id;

  RETURN QUERY SELECT * FROM public.colis WHERE bl_id = _bl_id ORDER BY numero_carton;
END;
$$;

GRANT EXECUTE ON FUNCTION public.creer_colisage(uuid, jsonb) TO authenticated;
