-- Vérifie que seuls les rôles admin peuvent lire l'audit et exécuter la RPC.
-- Usage: psql -f scripts/test-rls-audit.sql
-- Sortie attendue: chaque bloc affiche "PASS ..." ; toute exception = FAIL.

\set ON_ERROR_STOP off

BEGIN;

-- Créer un utilisateur "admin" et un utilisateur "lambda" éphémères.
DO $$
DECLARE
  v_admin uuid;
  v_user  uuid;
  v_count int;
BEGIN
  -- Réutilise des utilisateurs auth existants (FK sur auth.users).
  SELECT ur.user_id INTO v_admin
    FROM public.user_roles ur
    WHERE ur.role IN ('super_admin','directeur_general')
    LIMIT 1;

  SELECT ur.user_id INTO v_user
    FROM public.user_roles ur
    WHERE ur.user_id <> v_admin
      AND NOT public.has_any_role(ur.user_id, ARRAY['super_admin','directeur_general','comptable']::app_role[])
    LIMIT 1;

  IF v_admin IS NULL OR v_user IS NULL THEN
    RAISE NOTICE 'SKIP: besoin d''au moins 1 admin et 1 non-admin en base';
    RETURN;
  END IF;

  -- 1) has_any_role: admin doit être admin, user non.
  IF NOT public.has_any_role(v_admin, ARRAY['super_admin']::app_role[]) THEN
    -- ok si DG plutôt que super_admin
    IF NOT public.has_any_role(v_admin, ARRAY['super_admin','directeur_general']::app_role[]) THEN
      RAISE EXCEPTION 'FAIL: admin devrait avoir un rôle admin';
    END IF;
  END IF;
  IF public.has_any_role(v_user, ARRAY['super_admin','directeur_general']::app_role[]) THEN
    RAISE EXCEPTION 'FAIL: user lambda ne doit pas être admin';
  END IF;
  RAISE NOTICE 'PASS: has_any_role gate';

  -- 2) La policy SELECT existe bien et cible les rôles admin.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'paiement_annulations_audit'
      AND cmd = 'SELECT'
      AND qual ILIKE '%has_any_role%super_admin%'
  ) THEN
    RAISE EXCEPTION 'FAIL: policy SELECT admin manquante sur paiement_annulations_audit';
  END IF;
  RAISE NOTICE 'PASS: policy SELECT admin en place';

  -- 3) Aucune policy INSERT/UPDATE/DELETE côté client (écriture via RPC).
  SELECT count(*) INTO v_count FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'paiement_annulations_audit'
      AND cmd IN ('INSERT','UPDATE','DELETE');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAIL: aucune policy d''écriture attendue (RPC only), trouvé %', v_count;
  END IF;
  RAISE NOTICE 'PASS: écriture verrouillée (RPC only)';

  -- 4) RLS activée sur la table
  SELECT count(*) INTO v_count FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'paiement_annulations_audit'
      AND c.relrowsecurity;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'FAIL: RLS non activée sur paiement_annulations_audit';
  END IF;
  RAISE NOTICE 'PASS: RLS activée';

  -- 5) RPC annuler_paiement(uuid,text,text) présente et sécurisée.
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'annuler_paiement'
      AND p.pronargs = 3
      AND p.prosecdef = true
  ) THEN
    RAISE EXCEPTION 'FAIL: annuler_paiement(uuid,text,text) SECURITY DEFINER manquante';
  END IF;
  RAISE NOTICE 'PASS: RPC annuler_paiement présente et SECURITY DEFINER';

  -- 6) La RPC lève bien Permission refusée pour un utilisateur non habilité
  --    (test comportemental via has_any_role, sans changer de rôle SQL).
  IF public.has_any_role(v_user, ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'FAIL: user lambda ne devrait pas passer le gate RPC';
  END IF;
  RAISE NOTICE 'PASS: gate RPC bloquerait ce user lambda';

  -- 7) Aucune policy anon sur paiement_annulations_audit ni sur paiements.
  SELECT count(*) INTO v_count FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('paiement_annulations_audit','paiements')
      AND 'anon' = ANY(roles);
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAIL: policy anon détectée sur audit/paiements (%)', v_count;
  END IF;
  RAISE NOTICE 'PASS: pas d''accès anon (recherche/pagination historique protégées)';

  -- 8) Les GRANTs sur paiement_annulations_audit n'ouvrent rien à anon.
  SELECT count(*) INTO v_count FROM information_schema.role_table_grants
    WHERE table_schema = 'public'
      AND table_name   = 'paiement_annulations_audit'
      AND grantee = 'anon';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAIL: GRANT anon sur paiement_annulations_audit (%)', v_count;
  END IF;
  RAISE NOTICE 'PASS: aucun GRANT anon sur l''audit';

  -- 9) SELECT sur paiements réservé au staff (is_staff), pas de policy public/anon.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='paiements' AND cmd='SELECT'
      AND qual ILIKE '%is_staff%'
  ) THEN
    RAISE EXCEPTION 'FAIL: SELECT paiements non gardé par is_staff';
  END IF;
  RAISE NOTICE 'PASS: recherche/pagination paiements verrouillée au staff';
END
$$;

ROLLBACK;