CREATE OR REPLACE FUNCTION public.creer_et_valider_specimen_avec_lignes(
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
BEGIN
  RAISE LOG '[specimens] creer_et_valider_specimen_avec_lignes start user=% client=% lignes=%',
    auth.uid(), _client_id, COALESCE(jsonb_array_length(_lignes), 0);

  SELECT * INTO v_spec
  FROM public.creer_specimen_avec_lignes(
    _date_remise,
    _motif,
    _observations,
    _client_id,
    _beneficiaire_nom,
    _representant_nom,
    _donneur_nom,
    _telephone,
    _etablissement,
    _ville,
    _adresse,
    _lignes
  );

  PERFORM * FROM public.valider_specimen(v_spec.specimen_id);

  SELECT * INTO v_spec
  FROM public.specimens
  WHERE specimen_id = v_spec.specimen_id;

  RAISE LOG '[specimens] creer_et_valider_specimen_avec_lignes success specimen=% reference=% statut=% total=%',
    v_spec.specimen_id, v_spec.reference, v_spec.statut, v_spec.total_quantite;

  RETURN v_spec;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[specimens] creer_et_valider_specimen_avec_lignes error sqlstate=% message=%', SQLSTATE, SQLERRM;
  RAISE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.creer_et_valider_specimen_avec_lignes(date, text, text, uuid, text, text, text, text, text, text, text, jsonb) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.creer_et_valider_specimen_avec_lignes(date, text, text, uuid, text, text, text, text, text, text, text, jsonb) TO authenticated;