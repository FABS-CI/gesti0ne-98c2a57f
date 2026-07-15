-- ============================================================================
-- Tests RLS par rôle (admin / staff / user standard)
-- ----------------------------------------------------------------------------
-- Usage :
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_permissions.sql
--
-- Prérequis : renseigner 3 UUIDs valides dans la section CONFIG ci-dessous.
--   - :admin_uid    → utilisateur avec rôle 'admin' (has_role(uid,'admin'))
--   - :staff_uid    → utilisateur is_staff() = true (non admin)
--   - :user_uid     → utilisateur standard (ni staff, ni admin)
--
-- Chaque bloc :
--   1. Réinitialise le rôle Postgres à `authenticated`
--   2. Injecte le JWT claims (sub = user_id)
--   3. Exécute la requête attendue
--   4. RAISE EXCEPTION si le résultat ne correspond pas
-- ============================================================================

\set admin_uid   '\'00000000-0000-0000-0000-000000000001\''
\set staff_uid   '\'00000000-0000-0000-0000-000000000002\''
\set user_uid    '\'00000000-0000-0000-0000-000000000003\''

\echo '=== Tests RLS : tables sensibles ==='

-- ---------------------------------------------------------------------------
-- Helper : exécute un bloc dans le contexte d'un user donné
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._test_as(uid uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated')::text, true);
END;
$$;

CREATE OR REPLACE FUNCTION public._expect(cond boolean, msg text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT cond THEN
    RAISE EXCEPTION 'FAIL: %', msg;
  ELSE
    RAISE NOTICE 'PASS: %', msg;
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- Test 1 : soldes_ouverture_clients — lecture réservée admin/staff
-- ---------------------------------------------------------------------------
DO $$
DECLARE n int;
BEGIN
  -- admin : doit pouvoir lire
  PERFORM public._test_as(:admin_uid);
  SELECT count(*) INTO n FROM public.soldes_ouverture_clients;
  PERFORM public._expect(n >= 0, 'admin peut lire soldes_ouverture_clients');

  -- staff : doit pouvoir lire
  PERFORM public._test_as(:staff_uid);
  SELECT count(*) INTO n FROM public.soldes_ouverture_clients;
  PERFORM public._expect(n >= 0, 'staff peut lire soldes_ouverture_clients');

  -- user standard : RLS filtre → 0 lignes visibles
  PERFORM public._test_as(:user_uid);
  SELECT count(*) INTO n FROM public.soldes_ouverture_clients;
  PERFORM public._expect(n = 0, 'user standard ne voit pas soldes_ouverture_clients');
END $$;

-- ---------------------------------------------------------------------------
-- Test 2 : soldes_ouverture_fournisseurs — idem
-- ---------------------------------------------------------------------------
DO $$
DECLARE n int;
BEGIN
  PERFORM public._test_as(:admin_uid);
  SELECT count(*) INTO n FROM public.soldes_ouverture_fournisseurs;
  PERFORM public._expect(n >= 0, 'admin peut lire soldes_ouverture_fournisseurs');

  PERFORM public._test_as(:user_uid);
  SELECT count(*) INTO n FROM public.soldes_ouverture_fournisseurs;
  PERFORM public._expect(n = 0, 'user standard ne voit pas soldes_ouverture_fournisseurs');
END $$;

-- ---------------------------------------------------------------------------
-- Test 3 : exercice_cloture_journal — réservé admin/staff
-- ---------------------------------------------------------------------------
DO $$
DECLARE n int;
BEGIN
  PERFORM public._test_as(:staff_uid);
  SELECT count(*) INTO n FROM public.exercice_cloture_journal;
  PERFORM public._expect(n >= 0, 'staff peut lire exercice_cloture_journal');

  PERFORM public._test_as(:user_uid);
  SELECT count(*) INTO n FROM public.exercice_cloture_journal;
  PERFORM public._expect(n = 0, 'user standard ne voit pas exercice_cloture_journal');
END $$;

-- ---------------------------------------------------------------------------
-- Test 4 : tournees — staff only
-- ---------------------------------------------------------------------------
DO $$
DECLARE n int;
BEGIN
  PERFORM public._test_as(:staff_uid);
  SELECT count(*) INTO n FROM public.tournees;
  PERFORM public._expect(n >= 0, 'staff peut lire tournees');

  PERFORM public._test_as(:user_uid);
  SELECT count(*) INTO n FROM public.tournees;
  PERFORM public._expect(n = 0, 'user standard ne voit pas tournees');
END $$;

-- ---------------------------------------------------------------------------
-- Test 5 : rbac_roles / rbac_permissions — staff only
-- ---------------------------------------------------------------------------
DO $$
DECLARE n int;
BEGIN
  PERFORM public._test_as(:staff_uid);
  SELECT count(*) INTO n FROM public.rbac_roles;
  PERFORM public._expect(n >= 0, 'staff peut lire rbac_roles');

  PERFORM public._test_as(:user_uid);
  SELECT count(*) INTO n FROM public.rbac_roles;
  PERFORM public._expect(n = 0, 'user standard ne voit pas rbac_roles');

  PERFORM public._test_as(:user_uid);
  SELECT count(*) INTO n FROM public.rbac_permissions;
  PERFORM public._expect(n = 0, 'user standard ne voit pas rbac_permissions');
END $$;

-- ---------------------------------------------------------------------------
-- Test 6 : colisage_responsables / preparateurs_colisage — staff only
-- ---------------------------------------------------------------------------
DO $$
DECLARE n int;
BEGIN
  PERFORM public._test_as(:user_uid);
  SELECT count(*) INTO n FROM public.colisage_responsables;
  PERFORM public._expect(n = 0, 'user standard ne voit pas colisage_responsables');

  SELECT count(*) INTO n FROM public.preparateurs_colisage;
  PERFORM public._expect(n = 0, 'user standard ne voit pas preparateurs_colisage');
END $$;

-- ---------------------------------------------------------------------------
-- Nettoyage
-- ---------------------------------------------------------------------------
RESET ROLE;
SELECT set_config('request.jwt.claims', '', false);
DROP FUNCTION IF EXISTS public._test_as(uuid);
DROP FUNCTION IF EXISTS public._expect(boolean, text);

\echo '=== Tous les tests RLS ont réussi ==='