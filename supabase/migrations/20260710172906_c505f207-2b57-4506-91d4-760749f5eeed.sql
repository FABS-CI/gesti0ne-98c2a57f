
-- 1. Supprime la fonction fantôme jamais appelée (les vraies fonctions sont
--    list_user_permissions, has_permission, has_permission_v2, has_module).
DROP FUNCTION IF EXISTS public.user_permissions(uuid);

-- 2. RPC atomique pour "Tout accorder / Tout retirer" (par module ou global).
--    Remplace les 36 aller-retour du client par une seule transaction serveur.
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
BEGIN
  -- Contrôle d'accès : seuls les porteurs de la permission
  -- roles_permissions.assigner_permission peuvent appeler ce RPC.
  PERFORM public.assert_permission('roles_permissions.assigner_permission');

  IF _codes IS NULL OR array_length(_codes, 1) IS NULL THEN
    RETURN 0;
  END IF;

  IF _accorde THEN
    -- Upsert en un seul appel : la table `rbac_role_permissions` a
    -- (role_id, permission_code) en clé, on écrase accorde=true.
    INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
    SELECT _role_id, code, true
    FROM unnest(_codes) AS code
    -- Filtre : ne conserve que les codes présents dans le catalogue,
    -- évite les orphelins silencieux.
    WHERE code IN (SELECT p.code FROM public.rbac_permissions p)
    ON CONFLICT (role_id, permission_code)
    DO UPDATE SET accorde = EXCLUDED.accorde;
    GET DIAGNOSTICS _affected = ROW_COUNT;
  ELSE
    DELETE FROM public.rbac_role_permissions
    WHERE role_id = _role_id
      AND permission_code = ANY(_codes);
    GET DIAGNOSTICS _affected = ROW_COUNT;
  END IF;

  RETURN _affected;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rbac_bulk_set_permissions(uuid, text[], boolean)
  TO authenticated;
