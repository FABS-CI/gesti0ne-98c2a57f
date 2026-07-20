
-- Phase 2 RBAC v2 : dépendances + diagnostic + audit filtrable

-- 1) Seed automatique des dépendances : toute action non-'voir' d'une même ressource nécessite '.voir'
INSERT INTO public.rbac2_perm_deps(perm_code, requires_code)
SELECT p1.code, p2.code
FROM public.rbac2_permissions p1
JOIN public.rbac2_permissions p2
  ON p2.resource_code = p1.resource_code
 AND p2.action = 'voir'
WHERE p1.action <> 'voir'
ON CONFLICT DO NOTHING;

-- 2) Fermeture transitive d'une permission (dépendances)
CREATE OR REPLACE FUNCTION public.rbac2_deps_transitive(_perm_code text)
RETURNS TABLE(perm_code text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH RECURSIVE r AS (
    SELECT requires_code AS code FROM public.rbac2_perm_deps WHERE perm_code = _perm_code
    UNION
    SELECT d.requires_code FROM public.rbac2_perm_deps d JOIN r ON d.perm_code = r.code
  )
  SELECT code FROM r;
$$;
GRANT EXECUTE ON FUNCTION public.rbac2_deps_transitive(text) TO authenticated, service_role;

-- 3) Diagnostic RBAC : renvoie un JSON structuré des anomalies détectées
CREATE OR REPLACE FUNCTION public.rbac2_diagnose()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb := '{}'::jsonb;
BEGIN
  -- Doit être admin RBAC ou super_admin
  IF NOT (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_permission_v2(auth.uid(), 'rbac:admin')
  ) THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    -- Rôles sans aucune permission accordée
    'roles_sans_permission', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label)), '[]'::jsonb)
      FROM public.rbac2_roles r
      WHERE NOT EXISTS (
        SELECT 1 FROM public.rbac2_role_perms rp WHERE rp.role_code = r.code AND rp.granted
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.rbac2_role_parents rpar WHERE rpar.role_code = r.code
      )
    ),
    -- Rôles sans aucun utilisateur assigné
    'roles_sans_utilisateur', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label)), '[]'::jsonb)
      FROM public.rbac2_roles r
      WHERE NOT EXISTS (SELECT 1 FROM public.rbac2_user_roles ur WHERE ur.role_code = r.code)
    ),
    -- Grants orphelins : perm_code n'existe plus dans le catalogue
    'grants_orphelins', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('role', rp.role_code, 'perm', rp.perm_code)), '[]'::jsonb)
      FROM public.rbac2_role_perms rp
      WHERE NOT EXISTS (SELECT 1 FROM public.rbac2_permissions p WHERE p.code = rp.perm_code)
    ),
    -- Dépendances manquantes : rôle a une perm mais pas ses required
    'dependances_manquantes', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'role', rp.role_code, 'perm', rp.perm_code, 'manque', d.requires_code
      )), '[]'::jsonb)
      FROM public.rbac2_role_perms rp
      JOIN public.rbac2_perm_deps d ON d.perm_code = rp.perm_code
      WHERE rp.granted
        AND NOT EXISTS (
          SELECT 1 FROM public.rbac2_role_perms rp2
          WHERE rp2.role_code = rp.role_code
            AND rp2.perm_code = d.requires_code
            AND rp2.granted
        )
        -- Ignore si héritée via parent (approximation : présence chez un parent direct)
        AND NOT EXISTS (
          SELECT 1
          FROM public.rbac2_role_parents rpar
          JOIN public.rbac2_role_perms rp3 ON rp3.role_code = rpar.parent_code
          WHERE rpar.role_code = rp.role_code
            AND rp3.perm_code = d.requires_code
            AND rp3.granted
        )
    ),
    -- Ressources sans aucune permission dans le catalogue
    'ressources_sans_permission', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label)), '[]'::jsonb)
      FROM public.rbac2_resources r
      WHERE NOT EXISTS (SELECT 1 FROM public.rbac2_permissions p WHERE p.resource_code = r.code)
    ),
    -- Cycles d'héritage (détection simple : parent transitif == soi-même)
    'cycles_heritage', (
      WITH RECURSIVE chain AS (
        SELECT role_code, parent_code, 1 AS depth
        FROM public.rbac2_role_parents
        UNION
        SELECT c.role_code, p.parent_code, c.depth + 1
        FROM chain c JOIN public.rbac2_role_parents p ON p.role_code = c.parent_code
        WHERE c.depth < 20
      )
      SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object('role', role_code)), '[]'::jsonb)
      FROM chain WHERE role_code = parent_code
    ),
    'generated_at', to_jsonb(now())
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.rbac2_diagnose() TO authenticated, service_role;

-- 4) Recherche audit filtrable
CREATE OR REPLACE FUNCTION public.rbac2_audit_search(
  _actor uuid DEFAULT NULL,
  _target_type text DEFAULT NULL,
  _action text DEFAULT NULL,
  _from timestamptz DEFAULT NULL,
  _to timestamptz DEFAULT NULL,
  _limit int DEFAULT 200
)
RETURNS SETOF public.rbac2_audit
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.rbac2_audit
  WHERE (_actor IS NULL OR actor_id = _actor)
    AND (_target_type IS NULL OR target_type = _target_type)
    AND (_action IS NULL OR action = _action)
    AND (_from IS NULL OR at >= _from)
    AND (_to IS NULL OR at <= _to)
  ORDER BY at DESC
  LIMIT LEAST(COALESCE(_limit, 200), 1000);
$$;
GRANT EXECUTE ON FUNCTION public.rbac2_audit_search(uuid, text, text, timestamptz, timestamptz, int)
  TO authenticated, service_role;
