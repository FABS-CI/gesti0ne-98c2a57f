-- RBAC single-toggle hardening — reuse the atomic server path for one permission.
CREATE OR REPLACE FUNCTION public.rbac_set_role_permission(
  _role_id uuid,
  _code text,
  _accorde boolean
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF _code IS NULL OR btrim(_code) = '' THEN
    RETURN 0;
  END IF;

  RETURN public.rbac_bulk_set_permissions(_role_id, ARRAY[_code], _accorde);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rbac_set_role_permission(uuid, text, boolean)
  TO authenticated;