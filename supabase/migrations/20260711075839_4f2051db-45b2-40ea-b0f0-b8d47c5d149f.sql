CREATE OR REPLACE FUNCTION public.rbac_bulk_set_permissions(
  _role_id uuid,
  _codes text[],
  _accorde boolean
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _affected integer := 0;
  _valid_codes text[];
  _effective_codes text[];
BEGIN
  PERFORM public.assert_permission('roles_permissions.assigner_permission');

  IF _role_id IS NULL OR _codes IS NULL OR array_length(_codes, 1) IS NULL THEN
    RETURN 0;
  END IF;

  SELECT COALESCE(array_agg(DISTINCT p.code), ARRAY[]::text[])
  INTO _valid_codes
  FROM public.rbac_permissions p
  WHERE p.code = ANY(_codes);

  IF array_length(_valid_codes, 1) IS NULL THEN
    RETURN 0;
  END IF;

  IF _accorde THEN
    WITH requested AS (
      SELECT p.code, p.sous_module, p.action
      FROM public.rbac_permissions p
      WHERE p.code = ANY(_valid_codes)
    ), expanded AS (
      SELECT code FROM requested
      UNION
      SELECT p_view.code
      FROM requested r
      JOIN public.rbac_permissions p_view
        ON p_view.sous_module = r.sous_module
       AND p_view.action = 'voir'
      WHERE r.action <> 'voir'
    )
    SELECT COALESCE(array_agg(DISTINCT code), ARRAY[]::text[])
    INTO _effective_codes
    FROM expanded;

    INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
    SELECT _role_id, code, true
    FROM unnest(_effective_codes) AS code
    ON CONFLICT (role_id, permission_code)
    DO UPDATE SET accorde = EXCLUDED.accorde;
    GET DIAGNOSTICS _affected = ROW_COUNT;
  ELSE
    WITH requested AS (
      SELECT p.code, p.sous_module, p.action
      FROM public.rbac_permissions p
      WHERE p.code = ANY(_valid_codes)
    ), expanded AS (
      SELECT code FROM requested
      UNION
      SELECT p_action.code
      FROM requested r
      JOIN public.rbac_permissions p_action
        ON p_action.sous_module = r.sous_module
      WHERE r.action = 'voir'
    )
    SELECT COALESCE(array_agg(DISTINCT code), ARRAY[]::text[])
    INTO _effective_codes
    FROM expanded;

    DELETE FROM public.rbac_role_permissions
    WHERE role_id = _role_id
      AND permission_code = ANY(_effective_codes);
    GET DIAGNOSTICS _affected = ROW_COUNT;
  END IF;

  RETURN _affected;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rbac_bulk_set_permissions(uuid, text[], boolean) TO authenticated;