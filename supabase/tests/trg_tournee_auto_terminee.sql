-- Tests d'intégration pour trg_tournee_auto_terminee
-- À exécuter dans une transaction ROLLBACK afin de ne pas polluer la base :
--   BEGIN;  \i supabase/tests/trg_tournee_auto_terminee.sql  ROLLBACK;
-- Chaque scénario RAISE EXCEPTION en cas d'échec, sinon RAISE NOTICE 'OK'.

DO $$
DECLARE
  v_tid uuid;
  v_c1 uuid;
  v_c2 uuid;
  v_statut text;
  v_mode text;
  v_at timestamptz;
BEGIN
  ---------------------------------------------------------------------------
  -- Scénario 1 : tous les colis livrés (statut_logistique='livre')
  --   → statut doit passer à 'terminee', cloture_mode='auto', cloture_at NOT NULL
  ---------------------------------------------------------------------------
  INSERT INTO public.tournees(reference, date_tournee, statut)
  VALUES ('TEST-AUTO-1-'||gen_random_uuid(), CURRENT_DATE, 'en_cours')
  RETURNING tournee_id INTO v_tid;

  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('C1-'||v_tid, 'prepare', v_tid, 1) RETURNING colis_id INTO v_c1;
  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('C2-'||v_tid, 'prepare', v_tid, 1) RETURNING colis_id INTO v_c2;

  -- 1 sur 2 livré → tournée reste 'en_cours'
  UPDATE public.colis SET statut_logistique='livre' WHERE colis_id = v_c1;
  SELECT statut INTO v_statut FROM public.tournees WHERE tournee_id = v_tid;
  IF v_statut <> 'en_cours' THEN
    RAISE EXCEPTION 'FAIL S1a : statut=% (attendu en_cours)', v_statut;
  END IF;

  -- 2 sur 2 livrés → auto-clôture
  UPDATE public.colis SET statut_logistique='livre' WHERE colis_id = v_c2;
  SELECT statut, cloture_mode, cloture_at
    INTO v_statut, v_mode, v_at
    FROM public.tournees WHERE tournee_id = v_tid;
  IF v_statut <> 'terminee' OR v_mode <> 'auto' OR v_at IS NULL THEN
    RAISE EXCEPTION 'FAIL S1b : statut=%, mode=%, at=%', v_statut, v_mode, v_at;
  END IF;
  RAISE NOTICE 'OK S1 : auto-clôture via statut_logistique=livre';

  ---------------------------------------------------------------------------
  -- Scénario 2 : livraison via date_livraison_reelle (statut resté prepare)
  ---------------------------------------------------------------------------
  INSERT INTO public.tournees(reference, date_tournee, statut)
  VALUES ('TEST-AUTO-2-'||gen_random_uuid(), CURRENT_DATE, 'en_cours')
  RETURNING tournee_id INTO v_tid;

  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('D1-'||v_tid, 'prepare', v_tid, 1) RETURNING colis_id INTO v_c1;

  UPDATE public.colis SET date_livraison_reelle = now() WHERE colis_id = v_c1;
  SELECT statut, cloture_mode INTO v_statut, v_mode
    FROM public.tournees WHERE tournee_id = v_tid;
  IF v_statut <> 'terminee' OR v_mode <> 'auto' THEN
    RAISE EXCEPTION 'FAIL S2 : statut=%, mode=%', v_statut, v_mode;
  END IF;
  RAISE NOTICE 'OK S2 : auto-clôture via date_livraison_reelle';

  ---------------------------------------------------------------------------
  -- Scénario 3 : livraison partielle → tournée NE DOIT PAS se clôturer
  ---------------------------------------------------------------------------
  INSERT INTO public.tournees(reference, date_tournee, statut)
  VALUES ('TEST-AUTO-3-'||gen_random_uuid(), CURRENT_DATE, 'en_cours')
  RETURNING tournee_id INTO v_tid;

  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('E1-'||v_tid, 'prepare', v_tid, 1) RETURNING colis_id INTO v_c1;
  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('E2-'||v_tid, 'prepare', v_tid, 1) RETURNING colis_id INTO v_c2;
  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('E3-'||v_tid, 'prepare', v_tid, 1);

  UPDATE public.colis SET statut_logistique='livre' WHERE colis_id IN (v_c1, v_c2);
  SELECT statut INTO v_statut FROM public.tournees WHERE tournee_id = v_tid;
  IF v_statut = 'terminee' THEN
    RAISE EXCEPTION 'FAIL S3 : clôture prématurée alors que 1 colis non livré';
  END IF;
  RAISE NOTICE 'OK S3 : pas de clôture tant qu''un colis reste non livré';

  ---------------------------------------------------------------------------
  -- Scénario 4 : tournée déjà 'annulee' → jamais ré-ouverte ni clôturée
  ---------------------------------------------------------------------------
  INSERT INTO public.tournees(reference, date_tournee, statut)
  VALUES ('TEST-AUTO-4-'||gen_random_uuid(), CURRENT_DATE, 'annulee')
  RETURNING tournee_id INTO v_tid;

  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('F1-'||v_tid, 'livre', v_tid, 1);

  SELECT statut INTO v_statut FROM public.tournees WHERE tournee_id = v_tid;
  IF v_statut <> 'annulee' THEN
    RAISE EXCEPTION 'FAIL S4 : statut=% (attendu annulee)', v_statut;
  END IF;
  RAISE NOTICE 'OK S4 : tournée annulee non modifiée';

  ---------------------------------------------------------------------------
  -- Scénario 5 : aucun colis affecté → statut inchangé
  ---------------------------------------------------------------------------
  INSERT INTO public.tournees(reference, date_tournee, statut)
  VALUES ('TEST-AUTO-5-'||gen_random_uuid(), CURRENT_DATE, 'en_cours')
  RETURNING tournee_id INTO v_tid;

  -- Insert puis retire l'affectation pour déclencher le trigger sans colis restant
  INSERT INTO public.colis(reference, statut_logistique, tournee_id, nb_cartons)
  VALUES ('G1-'||v_tid, 'livre', v_tid, 1) RETURNING colis_id INTO v_c1;
  UPDATE public.colis SET tournee_id = NULL WHERE colis_id = v_c1;

  SELECT statut INTO v_statut FROM public.tournees WHERE tournee_id = v_tid;
  IF v_statut = 'terminee' THEN
    RAISE EXCEPTION 'FAIL S5 : clôture avec 0 colis affecté';
  END IF;
  RAISE NOTICE 'OK S5 : pas de clôture quand 0 colis affecté';

  RAISE NOTICE '=== TOUS LES SCÉNARIOS OK ===';
END $$;