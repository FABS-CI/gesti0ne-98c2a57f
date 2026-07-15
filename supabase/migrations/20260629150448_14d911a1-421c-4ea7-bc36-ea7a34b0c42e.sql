CREATE OR REPLACE FUNCTION public.creer_specimen_avec_lignes(
  _date_remise date,
  _motif text,
  _observations text,
  _client_id uuid,
  _beneficiaire_nom text,
  _representant_nom text,
  _donneur_nom text,
  _telephone text,
  _etablissement text,
  _ville text,
  _adresse text,
  _lignes jsonb
)
RETURNS public.specimens
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spec public.specimens%ROWTYPE;
  v_ligne jsonb;
  v_ref text;
  v_total_quantite integer := 0;
  v_montant_theorique numeric := 0;
  v_beneficiaire text;
  v_date date := COALESCE(_date_remise, CURRENT_DATE);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour enregistrer une remise de spécimens'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_beneficiaire := NULLIF(BTRIM(COALESCE(_beneficiaire_nom, _etablissement, '')), '');
  IF _client_id IS NULL AND v_beneficiaire IS NULL THEN
    RAISE EXCEPTION 'Sélectionnez un client ou renseignez un établissement bénéficiaire';
  END IF;

  IF NULLIF(BTRIM(COALESCE(_donneur_nom, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Le nom du donneur des spécimens est obligatoire';
  END IF;

  IF _lignes IS NULL OR jsonb_typeof(_lignes) <> 'array' OR jsonb_array_length(_lignes) = 0 THEN
    RAISE EXCEPTION 'Ajoutez au moins un article';
  END IF;

  SELECT 'SPC-' || to_char(v_date, 'YYYYMMDD') || '-' || lpad((COUNT(*) + 1)::text, 4, '0')
    INTO v_ref
    FROM public.specimens
   WHERE date_remise = v_date;

  INSERT INTO public.specimens (
    reference,
    date_remise,
    gestionnaire_id,
    gestionnaire_nom,
    motif,
    observations,
    client_id,
    beneficiaire_nom,
    representant_nom,
    donneur_nom,
    telephone,
    etablissement,
    ville,
    adresse,
    statut,
    created_by
  )
  VALUES (
    v_ref,
    v_date,
    auth.uid(),
    COALESCE(auth.jwt() -> 'user_metadata' ->> 'nom_complet', auth.jwt() ->> 'email'),
    NULLIF(BTRIM(COALESCE(_motif, '')), ''),
    NULLIF(BTRIM(COALESCE(_observations, '')), ''),
    _client_id,
    v_beneficiaire,
    NULLIF(BTRIM(COALESCE(_representant_nom, '')), ''),
    NULLIF(BTRIM(COALESCE(_donneur_nom, '')), ''),
    NULLIF(BTRIM(COALESCE(_telephone, '')), ''),
    NULLIF(BTRIM(COALESCE(_etablissement, v_beneficiaire, '')), ''),
    NULLIF(BTRIM(COALESCE(_ville, '')), ''),
    NULLIF(BTRIM(COALESCE(_adresse, '')), ''),
    'brouillon',
    auth.uid()
  )
  RETURNING * INTO v_spec;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(_lignes)
  LOOP
    IF COALESCE((v_ligne ->> 'quantite')::integer, 0) <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide pour %', COALESCE(v_ligne ->> 'designation', 'un produit');
    END IF;

    INSERT INTO public.specimen_lignes (
      specimen_id,
      produit_id,
      reference_produit,
      designation,
      quantite,
      prix_unitaire_theorique,
      total_ligne
    )
    VALUES (
      v_spec.specimen_id,
      (v_ligne ->> 'produit_id')::uuid,
      NULLIF(v_ligne ->> 'reference_produit', ''),
      COALESCE(NULLIF(v_ligne ->> 'designation', ''), 'Produit'),
      (v_ligne ->> 'quantite')::integer,
      COALESCE((v_ligne ->> 'prix_unitaire_theorique')::numeric, 0),
      COALESCE((v_ligne ->> 'quantite')::integer, 0) * COALESCE((v_ligne ->> 'prix_unitaire_theorique')::numeric, 0)
    );
  END LOOP;

  SELECT
    COALESCE(SUM(quantite), 0),
    COALESCE(SUM(total_ligne), 0)
  INTO v_total_quantite, v_montant_theorique
  FROM public.specimen_lignes
  WHERE specimen_id = v_spec.specimen_id;

  UPDATE public.specimens
     SET total_quantite = v_total_quantite,
         montant_theorique = v_montant_theorique,
         updated_at = now()
   WHERE specimen_id = v_spec.specimen_id
   RETURNING * INTO v_spec;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
  VALUES (auth.uid(), 'create_specimen', 'specimens', v_spec.specimen_id::text);

  RETURN v_spec;
END;
$$;

GRANT EXECUTE ON FUNCTION public.creer_specimen_avec_lignes(date, text, text, uuid, text, text, text, text, text, text, text, jsonb) TO authenticated;