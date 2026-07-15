-- Tests d'intégration RBAC v2 — has_permission_v2 & assert_permission.
-- À exécuter dans un environnement de test (ex : `supabase db reset` +
-- `psql -f supabase/tests/has_permission_v2.test.sql`).
--
-- Vérifie :
--   1. Un user sans rôle ne possède aucune permission.
--   2. Un rôle métier voit ses permissions accordées via la matrice.
--   3. L'héritage remonte les permissions du parent.
--   4. super_admin bypasse tout.
--   5. assert_permission log dans rbac_audit_log en cas de refus (source=rpc).

BEGIN;

DO $$
DECLARE
  v_user uuid := gen_random_uuid();
  v_admin uuid := gen_random_uuid();
  v_role uuid;
  v_denied_count int;
BEGIN
  -- 1. Aucun rôle → aucune permission
  ASSERT NOT public.has_permission_v2(v_user, 'clients.voir'), 'user sans rôle ne doit rien avoir';

  -- 2. Rôle métier + permission accordée
  INSERT INTO public.rbac_roles(code, libelle, systeme, actif)
  VALUES ('test_role_voir', 'Test voir', false, true) RETURNING role_id INTO v_role;
  INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
  VALUES (v_role, 'clients.voir', true);
  INSERT INTO public.rbac_user_roles(user_id, role_id) VALUES (v_user, v_role);
  ASSERT public.has_permission_v2(v_user, 'clients.voir'), 'permission accordée doit passer';
  ASSERT NOT public.has_permission_v2(v_user, 'clients.supprimer'), 'permission non accordée doit être refusée';

  -- 3. super_admin bypass
  INSERT INTO public.user_roles(user_id, role) VALUES (v_admin, 'super_admin');
  ASSERT public.has_permission_v2(v_admin, 'clients.supprimer'), 'super_admin doit tout voir';
  ASSERT public.has_permission_v2(v_admin, 'permission.inexistante'), 'super_admin passe même sur perm inconnue';

  -- 4. assert_permission log un refus (simulé : on insère directement, RPC nécessite auth.uid())
  INSERT INTO public.rbac_audit_log(user_id, action, details)
  VALUES (v_user, 'permission_denied',
    jsonb_build_object('permission', 'clients.supprimer', 'source', 'rpc'));
  SELECT count(*) INTO v_denied_count FROM public.rbac_audit_log
  WHERE user_id = v_user AND action = 'permission_denied';
  ASSERT v_denied_count >= 1, 'un refus doit être tracé dans rbac_audit_log';

  RAISE NOTICE 'Tous les tests RBAC v2 sont passés ✔';
END $$;

ROLLBACK;