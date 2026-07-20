
-- ============================================================
-- RBAC v2 · Phase 3 — Moteur de synchronisation du catalogue
-- ============================================================

-- Domaine + module fallback pour héberger les ressources créées automatiquement
INSERT INTO public.rbac2_domains(code, label, icon, sort)
VALUES ('_non_classe', 'Non classé', 'inbox', 9999)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.rbac2_modules(code, domain_code, label, icon, sort)
VALUES ('_non_classe', '_non_classe', 'Ressources à classer', 'inbox', 9999)
ON CONFLICT (code) DO NOTHING;

-- ---------- rbac2_list_rpcs ----------
-- Liste des fonctions publiques (RPC) exposables via PostgREST.
CREATE OR REPLACE FUNCTION public.rbac2_list_rpcs()
RETURNS TABLE (name text, is_security_definer boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT p.proname::text,
         p.prosecdef
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname NOT LIKE 'pg_%'
     AND p.proname NOT LIKE 'rbac2_%'  -- exclut la plomberie RBAC
   ORDER BY p.proname;
$$;

GRANT EXECUTE ON FUNCTION public.rbac2_list_rpcs() TO authenticated, service_role;

-- ---------- rbac2_sync_catalog ----------
-- Reçoit un inventaire côté client (permissions + routes) et upsert
-- les ressources/permissions manquantes. Retourne un rapport JSON.
-- Aucun droit n'est modifié : les nouvelles permissions ne sont accordées
-- à personne, elles apparaissent simplement dans le catalogue.
CREATE OR REPLACE FUNCTION public.rbac2_sync_catalog(_inventory jsonb, _apply boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  _uid uuid := auth.uid();
  _perm text;
  _resource text;
  _action text;
  _created_resources jsonb := '[]'::jsonb;
  _created_permissions jsonb := '[]'::jsonb;
  _orphan_permissions jsonb := '[]'::jsonb;
  _orphan_resources jsonb := '[]'::jsonb;
  _unmapped_routes jsonb := '[]'::jsonb;
  _inventory_perms text[] := ARRAY(
    SELECT jsonb_array_elements_text(coalesce(_inventory->'permissions', '[]'::jsonb))
  );
  _rpcs jsonb;
BEGIN
  -- Autorisation : rbac:admin (via v2), fallback super_admin
  IF NOT (
    public.has_permission_v2(_uid, 'rbac.admin')
    OR public.has_permission_v2(_uid, 'roles_permissions.modifier')
    OR EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = _uid AND ur.role = 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Accès refusé — rôle rbac:admin requis' USING ERRCODE = '42501';
  END IF;

  -- 1) Ressources & permissions manquantes à créer
  FOREACH _perm IN ARRAY _inventory_perms LOOP
    _resource := split_part(_perm, '.', 1);
    _action   := split_part(_perm, '.', 2);
    IF _resource = '' OR _action = '' THEN CONTINUE; END IF;

    -- Ressource inexistante ?
    IF NOT EXISTS (SELECT 1 FROM public.rbac2_resources WHERE code = _resource) THEN
      _created_resources := _created_resources || jsonb_build_object(
        'code', _resource, 'module_code', '_non_classe'
      );
      IF _apply THEN
        INSERT INTO public.rbac2_resources(code, module_code, label, kind, sort)
        VALUES (_resource, '_non_classe', initcap(replace(_resource, '_', ' ')), 'route', 500)
        ON CONFLICT (code) DO NOTHING;
      END IF;
    END IF;

    -- Permission inexistante ?
    IF NOT EXISTS (SELECT 1 FROM public.rbac2_permissions WHERE code = _perm) THEN
      _created_permissions := _created_permissions || jsonb_build_object(
        'code', _perm, 'resource_code', _resource, 'action', _action
      );
      IF _apply THEN
        INSERT INTO public.rbac2_permissions(code, resource_code, action, label)
        VALUES (_perm, _resource, _action, _action || ' ' || _resource)
        ON CONFLICT (code) DO NOTHING;
      END IF;
    END IF;
  END LOOP;

  -- 2) Permissions présentes dans le catalogue mais absentes de l'inventaire
  _orphan_permissions := (
    SELECT coalesce(jsonb_agg(jsonb_build_object('code', p.code, 'label', p.label) ORDER BY p.code), '[]'::jsonb)
      FROM public.rbac2_permissions p
     WHERE NOT (p.code = ANY(_inventory_perms))
  );

  -- 3) Ressources sans aucune permission dans l'inventaire
  _orphan_resources := (
    SELECT coalesce(jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label) ORDER BY r.code), '[]'::jsonb)
      FROM public.rbac2_resources r
     WHERE NOT EXISTS (
       SELECT 1 FROM unnest(_inventory_perms) x
        WHERE split_part(x, '.', 1) = r.code
     )
  );

  -- 4) Routes inconnues transmises par le client (sans permission mappée)
  IF _inventory ? 'unmapped_routes' THEN
    _unmapped_routes := _inventory->'unmapped_routes';
  END IF;

  -- 5) Inventaire des RPC (pour info)
  SELECT coalesce(jsonb_agg(jsonb_build_object('name', name, 'security_definer', is_security_definer) ORDER BY name), '[]'::jsonb)
    INTO _rpcs
    FROM public.rbac2_list_rpcs();

  RETURN jsonb_build_object(
    'applied',              _apply,
    'inventory_size',       coalesce(array_length(_inventory_perms, 1), 0),
    'created_resources',    _created_resources,
    'created_permissions',  _created_permissions,
    'orphan_permissions',   _orphan_permissions,
    'orphan_resources',     _orphan_resources,
    'unmapped_routes',      _unmapped_routes,
    'rpcs',                 _rpcs,
    'generated_at',         now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rbac2_sync_catalog(jsonb, boolean) TO authenticated, service_role;

COMMENT ON FUNCTION public.rbac2_sync_catalog(jsonb, boolean) IS
'RBAC v2 · Phase 3 : synchronise le catalogue à partir d''un inventaire client (routes + permissions). _apply=false pour dry-run.';
