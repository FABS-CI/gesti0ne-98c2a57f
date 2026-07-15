DO $$
DECLARE
  v_super_admin uuid;
  v_target uuid;
  v_target_email text;
  v_count int := 0;
  v_snapshot jsonb;
BEGIN
  SELECT user_id INTO v_super_admin
  FROM public.user_roles
  WHERE role = 'super_admin'
  ORDER BY user_id LIMIT 1;

  IF v_super_admin IS NULL THEN
    RAISE EXCEPTION 'Aucun super_admin trouvé — abandon';
  END IF;

  FOR v_target, v_target_email IN
    SELECT p.id, p.email FROM public.profiles p
    WHERE p.id <> v_super_admin AND p.actif = true
  LOOP
    SELECT jsonb_build_object(
      'user_roles', COALESCE((SELECT jsonb_agg(role::text) FROM public.user_roles WHERE user_id = v_target), '[]'::jsonb),
      'rbac_user_roles', COALESCE((SELECT jsonb_agg(role_id) FROM public.rbac_user_roles WHERE user_id = v_target), '[]'::jsonb),
      'actif_avant', true,
      'email', v_target_email
    ) INTO v_snapshot;

    UPDATE public.profiles SET actif = false, updated_at = now() WHERE id = v_target;
    DELETE FROM public.user_roles WHERE user_id = v_target;
    DELETE FROM public.rbac_user_roles WHERE user_id = v_target;

    INSERT INTO public.rbac_audit_log (user_id, user_email, action, details, avant, apres)
    VALUES (
      v_super_admin,
      v_target_email,
      'user_deactivated_bulk',
      jsonb_build_object('cible_user_id', v_target, 'raison', 'Phase 2 refonte RBAC'),
      v_snapshot,
      jsonb_build_object('actif', false, 'roles_revoked', true)
    );

    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Utilisateurs désactivés : %', v_count;
END $$;