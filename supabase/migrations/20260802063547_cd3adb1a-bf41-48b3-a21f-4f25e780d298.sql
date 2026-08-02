
-- Lot 5 : RPC d'administration RBAC v3

CREATE OR REPLACE FUNCTION public.rbac3_admin_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.rbac3_can('administration.modifier') THEN
    RAISE EXCEPTION 'Accès refusé : droit administration.modifier requis';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac3_log(
  _action text, _cible_type text, _cible_id text,
  _role_code text DEFAULT NULL, _perm_code text DEFAULT NULL,
  _old jsonb DEFAULT NULL, _new jsonb DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.rbac3_audit(acteur_id, acteur_email, action, cible_type, cible_id, role_code, perm_code, ancienne_valeur, nouvelle_valeur)
  VALUES (auth.uid(), (SELECT email FROM public.profiles WHERE id = auth.uid()), _action, _cible_type, _cible_id, _role_code, _perm_code, _old, _new);
END;
$$;

-- Rôles ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rbac3_role_upsert(
  _code text, _label text, _description text DEFAULT NULL,
  _portee_globale boolean DEFAULT false, _statut text DEFAULT 'actif'
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _old jsonb; _clean text;
BEGIN
  PERFORM public.rbac3_admin_guard();
  _clean := lower(regexp_replace(trim(_code), '\s+', '_', 'g'));
  IF _clean = 'super_admin' THEN RAISE EXCEPTION 'Le rôle super_admin est protégé'; END IF;
  SELECT to_jsonb(r) INTO _old FROM public.rbac3_roles r WHERE r.code = _clean;

  INSERT INTO public.rbac3_roles(code, label, description, statut, portee_globale, systeme)
  VALUES (_clean, _label, _description, coalesce(_statut,'actif'), coalesce(_portee_globale,false), false)
  ON CONFLICT (code) DO UPDATE
    SET label = EXCLUDED.label,
        description = EXCLUDED.description,
        statut = EXCLUDED.statut,
        portee_globale = EXCLUDED.portee_globale,
        updated_at = now();

  PERFORM public.rbac3_log(CASE WHEN _old IS NULL THEN 'role_create' ELSE 'role_update' END,
    'role', _clean, _clean, NULL, _old,
    (SELECT to_jsonb(r) FROM public.rbac3_roles r WHERE r.code = _clean));
  RETURN _clean;
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac3_role_delete(_code text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _old jsonb; _n int;
BEGIN
  PERFORM public.rbac3_admin_guard();
  SELECT to_jsonb(r) INTO _old FROM public.rbac3_roles r WHERE r.code = _code;
  IF _old IS NULL THEN RAISE EXCEPTION 'Rôle introuvable'; END IF;
  IF (_old->>'systeme')::boolean OR _code = 'super_admin' THEN
    RAISE EXCEPTION 'Rôle système : suppression interdite';
  END IF;
  SELECT count(*) INTO _n FROM public.rbac3_user_roles WHERE role_code = _code;
  IF _n > 0 THEN RAISE EXCEPTION 'Rôle encore attribué à % utilisateur(s)', _n; END IF;

  DELETE FROM public.rbac3_role_permissions WHERE role_code = _code;
  DELETE FROM public.rbac3_roles WHERE code = _code;
  PERFORM public.rbac3_log('role_delete', 'role', _code, _code, NULL, _old, NULL);
END;
$$;

-- Matrice -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rbac3_perm_set(_role_code text, _perm_code text, _granted boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.rbac3_admin_guard();
  IF _role_code = 'super_admin' THEN RAISE EXCEPTION 'Les droits du super administrateur sont figés'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rbac3_permissions WHERE code = _perm_code) THEN
    RAISE EXCEPTION 'Permission inconnue : %', _perm_code;
  END IF;
  IF _granted THEN
    INSERT INTO public.rbac3_role_permissions(role_code, perm_code)
    VALUES (_role_code, _perm_code) ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.rbac3_role_permissions WHERE role_code = _role_code AND perm_code = _perm_code;
  END IF;
  PERFORM public.rbac3_log(CASE WHEN _granted THEN 'perm_grant' ELSE 'perm_revoke' END,
    'role_permission', _role_code || ':' || _perm_code, _role_code, _perm_code,
    to_jsonb(NOT _granted), to_jsonb(_granted));
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac3_perm_bulk_set(_role_code text, _perm_codes text[], _granted boolean)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _n int := 0;
BEGIN
  PERFORM public.rbac3_admin_guard();
  IF _role_code = 'super_admin' THEN RAISE EXCEPTION 'Les droits du super administrateur sont figés'; END IF;
  IF _granted THEN
    INSERT INTO public.rbac3_role_permissions(role_code, perm_code)
    SELECT _role_code, p.code FROM public.rbac3_permissions p WHERE p.code = ANY(_perm_codes)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS _n = ROW_COUNT;
  ELSE
    DELETE FROM public.rbac3_role_permissions WHERE role_code = _role_code AND perm_code = ANY(_perm_codes);
    GET DIAGNOSTICS _n = ROW_COUNT;
  END IF;
  PERFORM public.rbac3_log(CASE WHEN _granted THEN 'perm_bulk_grant' ELSE 'perm_bulk_revoke' END,
    'role_permission', _role_code, _role_code, NULL, NULL, to_jsonb(_perm_codes));
  RETURN _n;
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac3_role_copy_perms(_source text, _target text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _n int;
BEGIN
  PERFORM public.rbac3_admin_guard();
  IF _target = 'super_admin' THEN RAISE EXCEPTION 'Les droits du super administrateur sont figés'; END IF;
  DELETE FROM public.rbac3_role_permissions WHERE role_code = _target;
  INSERT INTO public.rbac3_role_permissions(role_code, perm_code)
  SELECT _target, perm_code FROM public.rbac3_role_permissions WHERE role_code = _source
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS _n = ROW_COUNT;
  PERFORM public.rbac3_log('perm_copy', 'role_permission', _target, _target, NULL,
    to_jsonb(_source), to_jsonb(_n));
  RETURN _n;
END;
$$;

-- Assignations --------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rbac3_user_role_set(_user_id uuid, _role_code text, _granted boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.rbac3_admin_guard();
  IF NOT EXISTS (SELECT 1 FROM public.rbac3_roles WHERE code = _role_code) THEN
    RAISE EXCEPTION 'Rôle inconnu : %', _role_code;
  END IF;
  IF _granted THEN
    INSERT INTO public.rbac3_user_roles(user_id, role_code, assigned_by)
    VALUES (_user_id, _role_code, auth.uid()) ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.rbac3_user_roles WHERE user_id = _user_id AND role_code = _role_code;
  END IF;
  PERFORM public.rbac3_log(CASE WHEN _granted THEN 'user_role_grant' ELSE 'user_role_revoke' END,
    'user_role', _user_id::text, _role_code, NULL, NULL, to_jsonb(_granted));
END;
$$;

REVOKE ALL ON FUNCTION public.rbac3_admin_guard() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_log(text,text,text,text,text,jsonb,jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_role_upsert(text,text,text,boolean,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_role_delete(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_perm_set(text,text,boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_perm_bulk_set(text,text[],boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_role_copy_perms(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rbac3_user_role_set(uuid,text,boolean) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.rbac3_role_upsert(text,text,text,boolean,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac3_role_delete(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac3_perm_set(text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac3_perm_bulk_set(text,text[],boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac3_role_copy_perms(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rbac3_user_role_set(uuid,text,boolean) TO authenticated;
