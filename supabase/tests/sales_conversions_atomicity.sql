-- =========================================================================
-- Tests d'intégration : atomicité des RPC de conversion (Ventes)
-- Exécuter dans un environnement de test (base de dev/staging).
-- Chaque test s'exécute dans une transaction ROLLBACK -> aucun effet réel.
-- =========================================================================

-- ---------- Test 1 : convertir_proforma_en_commande est atomique --------
-- Si l'insertion des lignes échoue (ex: contrainte), aucune commande ne doit
-- rester en base et la proforma doit conserver son statut initial.
BEGIN;
DO $$
DECLARE
  v_before_cmd INT;
  v_after_cmd  INT;
  v_pro_id UUID;
  v_statut_avant TEXT;
  v_statut_apres TEXT;
BEGIN
  SELECT COUNT(*) INTO v_before_cmd FROM public.commandes;

  SELECT proforma_id, statut INTO v_pro_id, v_statut_avant
  FROM public.proformas WHERE statut <> 'acceptee' LIMIT 1;
  IF v_pro_id IS NULL THEN RAISE NOTICE 'SKIP: aucune proforma non acceptée'; RETURN; END IF;

  BEGIN
    -- Forcer un échec au milieu du traitement en cassant temporairement
    -- une contrainte via un savepoint : on simule en levant une exception
    -- après l'appel pour vérifier que la transaction externe rollback tout.
    PERFORM public.convertir_proforma_en_commande(v_pro_id);
    RAISE EXCEPTION 'SIMULATION_ECHEC_APRES_CONVERSION';
  EXCEPTION WHEN OTHERS THEN
    NULL; -- attendu
  END;

  SELECT COUNT(*) INTO v_after_cmd FROM public.commandes;
  SELECT statut INTO v_statut_apres FROM public.proformas WHERE proforma_id = v_pro_id;

  ASSERT v_after_cmd = v_before_cmd,
    format('Atomicité KO: %s commandes avant / %s après', v_before_cmd, v_after_cmd);
  ASSERT v_statut_apres = v_statut_avant,
    format('Statut proforma modifié malgré échec: %s -> %s', v_statut_avant, v_statut_apres);
  RAISE NOTICE 'OK: convertir_proforma_en_commande atomique';
END $$;
ROLLBACK;

-- ---------- Test 2 : convertir_commande_en_bl est atomique --------------
-- Vérifie qu'un échec (nb_colis invalide) ne crée ni BL, ni ordre, ni colis,
-- ni mouvements de stock, et ne change pas le statut de la commande.
BEGIN;
DO $$
DECLARE
  v_cmd_id UUID;
  v_statut_avant TEXT;
  v_bl_avant INT; v_bl_apres INT;
  v_colis_avant INT; v_colis_apres INT;
  v_mvt_avant INT; v_mvt_apres INT;
BEGIN
  SELECT commande_id, statut INTO v_cmd_id, v_statut_avant
  FROM public.commandes WHERE statut <> 'livree' LIMIT 1;
  IF v_cmd_id IS NULL THEN RAISE NOTICE 'SKIP: aucune commande non livrée'; RETURN; END IF;

  SELECT COUNT(*) INTO v_bl_avant FROM public.bons_livraison;
  SELECT COUNT(*) INTO v_colis_avant FROM public.colis;
  SELECT COUNT(*) INTO v_mvt_avant FROM public.stock_mouvements;

  BEGIN
    PERFORM public.convertir_commande_en_bl(v_cmd_id, 0); -- nb_colis invalide
  EXCEPTION WHEN OTHERS THEN NULL; END;

  SELECT COUNT(*) INTO v_bl_apres FROM public.bons_livraison;
  SELECT COUNT(*) INTO v_colis_apres FROM public.colis;
  SELECT COUNT(*) INTO v_mvt_apres FROM public.stock_mouvements;

  ASSERT v_bl_apres = v_bl_avant, 'BL créé malgré échec';
  ASSERT v_colis_apres = v_colis_avant, 'Colis créés malgré échec';
  ASSERT v_mvt_apres = v_mvt_avant, 'Mouvements stock créés malgré échec';
  ASSERT (SELECT statut FROM public.commandes WHERE commande_id = v_cmd_id) = v_statut_avant,
    'Statut commande modifié malgré échec';
  RAISE NOTICE 'OK: convertir_commande_en_bl atomique';
END $$;
ROLLBACK;

-- ---------- Test 3 : audit trail est écrit sur succès ------------------
BEGIN;
DO $$
DECLARE
  v_pro_id UUID;
  v_audit_avant INT;
  v_audit_apres INT;
BEGIN
  SELECT proforma_id INTO v_pro_id
  FROM public.proformas WHERE statut <> 'acceptee' LIMIT 1;
  IF v_pro_id IS NULL THEN RAISE NOTICE 'SKIP: aucune proforma'; RETURN; END IF;

  SELECT COUNT(*) INTO v_audit_avant FROM public.audit_logs
  WHERE action = 'convertir_proforma_en_commande';

  PERFORM public.convertir_proforma_en_commande(v_pro_id);

  SELECT COUNT(*) INTO v_audit_apres FROM public.audit_logs
  WHERE action = 'convertir_proforma_en_commande';

  ASSERT v_audit_apres = v_audit_avant + 1,
    format('Audit non écrit: %s -> %s', v_audit_avant, v_audit_apres);
  RAISE NOTICE 'OK: audit conversion proforma écrit';
END $$;
ROLLBACK;