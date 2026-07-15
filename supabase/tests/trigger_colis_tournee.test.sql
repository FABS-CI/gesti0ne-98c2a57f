-- Test d'intégration : trigger trg_colis_sync_tournee
-- Exécution :  psql -f supabase/tests/trigger_colis_tournee.test.sql
-- Le script s'exécute dans une transaction et ROLLBACK en fin (aucune donnée persistée).

BEGIN;
SET LOCAL client_min_messages = WARNING;

DO $test$
DECLARE
  -- Dates isolées (futur lointain) pour éviter toute donnée réelle
  d_today date := date '2099-01-15';
  d_hier  date := date '2099-01-14';
  v_client uuid := gen_random_uuid();
  v_cmd    uuid := gen_random_uuid();
  v_veh    uuid;
  v_client2 uuid := gen_random_uuid();
  v_cmd2    uuid := gen_random_uuid();
  v_t_prep uuid := gen_random_uuid();
  v_t_encours uuid := gen_random_uuid();
  v_t_term uuid := gen_random_uuid();  -- statut terminee : ne doit PAS bouger
  v_t_annul uuid := gen_random_uuid(); -- statut annulee : ne doit PAS bouger
  v_t_hier uuid := gen_random_uuid();  -- autre jour : ne doit PAS bouger
  v_colis1 uuid := gen_random_uuid();
  r_prep record; r_encours record; r_term record; r_annul record; r_hier record;
BEGIN
  -- Fixtures minimales
  INSERT INTO public.clients(client_id, nom) VALUES (v_client, 'TEST_CLIENT_TRG');
  INSERT INTO public.commandes(commande_id, client_id, numero, date_commande)
    VALUES (v_cmd, v_client, 'TEST-CMD-TRG', d_today);
  INSERT INTO public.clients(client_id, nom) VALUES (v_client2, 'TEST_CLIENT_TRG2');
  INSERT INTO public.commandes(commande_id, client_id, numero, date_commande)
    VALUES (v_cmd2, v_client2, 'TEST-CMD-TRG2', d_today);
  INSERT INTO public.vehicules(immatriculation, marque, modele)
    VALUES ('TEST-IMMAT-42', 'X', 'Y') RETURNING vehicule_id INTO v_veh;

  INSERT INTO public.tournees(tournee_id, reference, date_tournee, statut, nb_colis, nb_cartons, nb_clients)
    VALUES
      (v_t_prep,    'TEST-PREP',    d_today, 'preparee', 0, 0, 0),
      (v_t_encours, 'TEST-ENCOURS', d_today, 'en_cours', 0, 0, 0),
      (v_t_term,    'TEST-TERM',    d_today, 'terminee', 0, 0, 0),
      (v_t_annul,   'TEST-ANNUL',   d_today, 'annulee',  0, 0, 0),
      (v_t_hier,    'TEST-HIER',    d_hier,  'preparee', 0, 0, 0);

  -- Étape 1 : INSERT de 3 colis du jour (2 clients distincts)
  INSERT INTO public.colis(colis_id, date_colisage, commande_id, nb_cartons, livreur_nom, responsable_nom, vehicule)
    VALUES
      (v_colis1,          d_today, v_cmd,  2, 'Alice', 'Bob', 'TEST-IMMAT-42'),
      (gen_random_uuid(), d_today, v_cmd,  3, 'Alice', 'Bob', 'TEST-IMMAT-42'),
      (gen_random_uuid(), d_today, v_cmd2, 5, 'Alice', 'Bob', 'TEST-IMMAT-42');

  SELECT * INTO r_prep FROM public.tournees WHERE tournee_id = v_t_prep;
  SELECT * INTO r_encours FROM public.tournees WHERE tournee_id = v_t_encours;
  SELECT * INTO r_term FROM public.tournees WHERE tournee_id = v_t_term;
  SELECT * INTO r_annul FROM public.tournees WHERE tournee_id = v_t_annul;
  SELECT * INTO r_hier FROM public.tournees WHERE tournee_id = v_t_hier;

  -- Agrégation initiale sur les 2 tournées éligibles
  ASSERT r_prep.nb_colis = 3    AND r_encours.nb_colis = 3,    format('nb_colis prep=%s encours=%s', r_prep.nb_colis, r_encours.nb_colis);
  ASSERT r_prep.nb_cartons = 10 AND r_encours.nb_cartons = 10, format('nb_cartons prep=%s encours=%s', r_prep.nb_cartons, r_encours.nb_cartons);
  ASSERT r_prep.nb_clients = 2  AND r_encours.nb_clients = 2,  format('nb_clients prep=%s encours=%s', r_prep.nb_clients, r_encours.nb_clients);
  ASSERT r_prep.chauffeur_nom = 'Alice',   format('chauffeur=%s', r_prep.chauffeur_nom);
  ASSERT r_prep.responsable_nom = 'Bob',   format('responsable=%s', r_prep.responsable_nom);
  ASSERT r_prep.vehicule_id = v_veh,       format('vehicule_id=%s attendu %s', r_prep.vehicule_id, v_veh);

  -- Statuts non éligibles : rien ne change
  ASSERT r_term.nb_colis = 0 AND r_term.nb_cartons = 0 AND r_term.nb_clients = 0,
    format('terminee modifiée: colis=%s cartons=%s clients=%s', r_term.nb_colis, r_term.nb_cartons, r_term.nb_clients);
  ASSERT r_annul.nb_colis = 0 AND r_annul.nb_cartons = 0 AND r_annul.nb_clients = 0,
    format('annulee modifiée: colis=%s cartons=%s clients=%s', r_annul.nb_colis, r_annul.nb_cartons, r_annul.nb_clients);
  ASSERT r_hier.nb_colis = 0 AND r_hier.nb_cartons = 0 AND r_hier.nb_clients = 0,
    format('hier modifiée: colis=%s cartons=%s clients=%s', r_hier.nb_colis, r_hier.nb_cartons, r_hier.nb_clients);

  -- Étape 2 : INSERT supplémentaire → agrégats recalculés (couvre le cas
  -- multi-INSERT sans nécessiter les droits UPDATE/DELETE).
  INSERT INTO public.colis(colis_id, date_colisage, commande_id, nb_cartons, livreur_nom, responsable_nom, vehicule)
    VALUES (gen_random_uuid(), d_today, v_cmd, 7, 'Alice', 'Bob', 'TEST-IMMAT-42');
  SELECT * INTO r_prep FROM public.tournees WHERE tournee_id = v_t_prep;
  ASSERT r_prep.nb_colis = 4    , format('après 2e INSERT nb_colis=%s attendu 4', r_prep.nb_colis);
  ASSERT r_prep.nb_cartons = 17 , format('après 2e INSERT nb_cartons=%s attendu 17', r_prep.nb_cartons);
  ASSERT r_prep.nb_clients = 2  , format('après 2e INSERT nb_clients=%s attendu 2', r_prep.nb_clients);

  -- Les statuts non éligibles restent à zéro même après plusieurs INSERTs
  SELECT * INTO r_term FROM public.tournees WHERE tournee_id = v_t_term;
  SELECT * INTO r_annul FROM public.tournees WHERE tournee_id = v_t_annul;
  ASSERT r_term.nb_colis = 0 AND r_annul.nb_colis = 0,
    format('statuts non éligibles modifiés: term=%s annul=%s', r_term.nb_colis, r_annul.nb_colis);

  -- Vérifie que la table de debug a bien enregistré chaque exécution
  ASSERT (SELECT count(*) FROM public.trigger_execution_log
          WHERE trigger_name = 'recalc_tournee_from_colis' AND target_date = d_today) >= 4,
    'trigger_execution_log doit contenir >=4 lignes pour d_today';

  RAISE WARNING '✅ Trigger colis → tournée : tous les asserts passent';
END $test$;

ROLLBACK;