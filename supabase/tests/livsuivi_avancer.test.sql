-- Test d'intégration : RPC public.livsuivi_avancer
-- Vérifie que chaque transition (direct + expedition) :
--   1. met à jour livsuivi_commandes.statut vers l'étape suivante,
--   2. écrit exactement une ligne dans livsuivi_historique avec la bonne étape.
-- Exécution :  psql -f supabase/tests/livsuivi_avancer.test.sql
-- Doit être joué en environnement de test (ex : `supabase db reset` puis
-- `psql -U postgres -f ...`) — l'insertion dans `auth.users` requiert le rôle
-- superuser. Le script tourne dans une transaction et ROLLBACK en fin
-- (aucune donnée persistée).
-- Le script tourne dans une transaction et ROLLBACK en fin.

BEGIN;
SET LOCAL client_min_messages = WARNING;

DO $test$
DECLARE
  v_user    uuid := gen_random_uuid();
  v_client  uuid := gen_random_uuid();
  v_cmd_d   uuid := gen_random_uuid();  -- commande direct
  v_cmd_e   uuid := gen_random_uuid();  -- commande expedition
  v_liv_d   uuid;
  v_liv_e   uuid;
  v_row     public.livsuivi_commandes;
  v_histo   int;
  -- Étapes attendues
  direct_steps    public.livsuivi_statut[] := ARRAY[
    'remise_livreur','depart_depot','arrive_client','livree'
  ]::public.livsuivi_statut[];
  expedition_steps public.livsuivi_statut[] := ARRAY[
    'remise_transporteur','expediee','arrivee_gare','retiree_client'
  ]::public.livsuivi_statut[];
  s public.livsuivi_statut;
BEGIN
  -- Auth simulée : on crée un user factice dans auth.users puis on lui
  -- attache le rôle super_admin (bypasse has_any_role).
  INSERT INTO auth.users(id, instance_id, aud, role, email,
                         encrypted_password, email_confirmed_at,
                         created_at, updated_at)
  VALUES (v_user, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'test-livsuivi@local',
          '', now(), now(), now());
  INSERT INTO public.user_roles(user_id, role) VALUES (v_user, 'super_admin');
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', v_user::text, 'email', 'test@livsuivi.local')::text,
    true
  );

  -- Fixtures : 2 commandes distinctes
  INSERT INTO public.clients(client_id, nom) VALUES (v_client, 'TEST_CLIENT_LIVSUIVI');
  INSERT INTO public.commandes(commande_id, client_id, numero, date_commande)
    VALUES (v_cmd_d, v_client, 'TEST-LIVSUIVI-D', date '2099-02-01'),
           (v_cmd_e, v_client, 'TEST-LIVSUIVI-E', date '2099-02-01');

  INSERT INTO public.livsuivi_commandes(commande_id, type_livraison, statut)
    VALUES (v_cmd_d, 'direct', 'preparee') RETURNING id INTO v_liv_d;
  INSERT INTO public.livsuivi_commandes(commande_id, type_livraison, statut)
    VALUES (v_cmd_e, 'expedition', 'preparee') RETURNING id INTO v_liv_e;

  ---------------------------------------------------------------------------
  -- Transitions directes : preparee → remise_livreur → depart_depot →
  --                        arrive_client → livree
  ---------------------------------------------------------------------------
  FOREACH s IN ARRAY direct_steps LOOP
    v_row := public.livsuivi_avancer(v_liv_d, s, '{}'::jsonb, 'auto-test');
    ASSERT v_row.statut = s,
      format('direct: statut attendu=% obtenu=%', s, v_row.statut);
    SELECT count(*) INTO v_histo FROM public.livsuivi_historique
      WHERE livraison_id = v_liv_d AND etape = s;
    ASSERT v_histo = 1,
      format('direct: historique manquant pour %', s);
  END LOOP;
  ASSERT v_row.cloturee IS TRUE, 'direct: la livraison doit être clôturée après « livree »';

  ---------------------------------------------------------------------------
  -- Transitions expédition : preparee → remise_transporteur → expediee →
  --                          arrivee_gare → retiree_client
  ---------------------------------------------------------------------------
  FOREACH s IN ARRAY expedition_steps LOOP
    v_row := public.livsuivi_avancer(v_liv_e, s, '{}'::jsonb, 'auto-test');
    ASSERT v_row.statut = s,
      format('expedition: statut attendu=% obtenu=%', s, v_row.statut);
    SELECT count(*) INTO v_histo FROM public.livsuivi_historique
      WHERE livraison_id = v_liv_e AND etape = s;
    ASSERT v_histo = 1,
      format('expedition: historique manquant pour %', s);
  END LOOP;
  ASSERT v_row.cloturee IS TRUE,
    'expedition: la livraison doit être clôturée après « retiree_client »';

  ---------------------------------------------------------------------------
  -- Transition interdite : après « livree » (direct), plus rien n'est autorisé.
  ---------------------------------------------------------------------------
  BEGIN
    PERFORM public.livsuivi_avancer(v_liv_d, 'remise_livreur'::public.livsuivi_statut,
      '{}'::jsonb, NULL);
    RAISE EXCEPTION 'Transition sur livraison clôturée aurait dû échouer';
  EXCEPTION WHEN raise_exception THEN
    -- OK : livsuivi_avancer refuse la transition
    NULL;
  END;

  -- Total historique : 4 étapes direct + 4 étapes expedition = 8
  SELECT count(*) INTO v_histo FROM public.livsuivi_historique
    WHERE livraison_id IN (v_liv_d, v_liv_e);
  ASSERT v_histo = 8,
    format('historique global attendu=8 obtenu=%', v_histo);

  RAISE NOTICE 'Tests livsuivi_avancer OK ✔ (8 transitions tracées)';
END $test$;

ROLLBACK;