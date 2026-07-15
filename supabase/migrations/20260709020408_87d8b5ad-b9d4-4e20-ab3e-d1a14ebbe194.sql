-- Purge des données de test pré-production
-- Désactive les triggers (audit, no_delete) pour permettre TRUNCATE atomique
SET session_replication_role = 'replica';

-- 1. Purge des tables transactionnelles (CASCADE résout toutes les FK internes)
TRUNCATE TABLE
  public.proformas, public.proforma_lignes,
  public.commandes, public.commande_lignes,
  public.achats, public.achat_lignes,
  public.bons_livraison, public.bons_retour,
  public.colis, public.colis_lignes, public.colis_statut_historique,
  public.colisage_modifications_historique, public.ordres_colisage,
  public.livraisons, public.livraisons_commande, public.livraison_commande_historique,
  public.livsuivi_commandes, public.livsuivi_historique, public.livsuivi_tournees,
  public.tournees, public.missions, public.expeditions,
  public.factures, public.avoirs, public.paiements,
  public.retours, public.retour_lignes,
  public.ecritures_comptables, public.ecriture_lignes,
  public.transferts, public.transfert_lignes,
  public.inventaires, public.inventaire_lignes,
  public.stock_mouvements,
  public.specimens, public.specimen_lignes,
  public.incidents, public.incident_lignes, public.incident_alerts,
  public.notifications, public.notifications_purge_log, public.historique_envois,
  public.fne_factures, public.fne_logs,
  public.audit_events, public.audit_events_archive, public.audit_logs, public.rbac_audit_log,
  public.login_history, public.mfa_otp_attempts, public.mfa_session_validations,
  public.workflow_approvals, public.documents,
  public.couts_logistiques_audit, public.finances_corrections_audit,
  public.stock_corrections_audit, public.paiement_annulations_audit,
  public.exercice_cloture_journal,
  public.perf_query_log, public.trigger_execution_log, public.user_action_stats,
  public.client_fidelite_mouvements, public.transactions
RESTART IDENTITY CASCADE;

-- 2. Réinitialisation complète du stock (préserve les lignes produit×dépôt)
UPDATE public.stocks_depots SET quantite = 0, updated_at = now();

-- 3. Réinitialisation des séquences de numérotation transactionnelles (à 1)
--    (produit_ref_seq, clients_ref_seq, employe_ref_seq préservées : données de référence)
ALTER SEQUENCE public.proformas_ref_seq       RESTART WITH 1;
ALTER SEQUENCE public.commande_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.achat_ref_seq           RESTART WITH 1;
ALTER SEQUENCE public.bons_livraison_ref_seq  RESTART WITH 1;
ALTER SEQUENCE public.bons_retour_ref_seq     RESTART WITH 1;
ALTER SEQUENCE public.colis_ref_seq           RESTART WITH 1;
ALTER SEQUENCE public.factures_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.avoirs_ref_seq          RESTART WITH 1;
ALTER SEQUENCE public.paiements_ref_seq       RESTART WITH 1;
ALTER SEQUENCE public.ecriture_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.transaction_ref_seq     RESTART WITH 1;
ALTER SEQUENCE public.retours_ref_seq         RESTART WITH 1;
ALTER SEQUENCE public.livraisons_ref_seq      RESTART WITH 1;
ALTER SEQUENCE public.missions_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.workflow_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.incidents_ref_seq       RESTART WITH 1;
ALTER SEQUENCE public.inventaires_ref_seq     RESTART WITH 1;
ALTER SEQUENCE public.fne_ref_seq             RESTART WITH 1;
ALTER SEQUENCE public.couts_ref_seq           RESTART WITH 1;
ALTER SEQUENCE public.audit_events_seq_seq    RESTART WITH 1;

-- 4. Purge des paramètres temporaires d'audit E2E
DELETE FROM public.parametres WHERE cle LIKE 'audit_e2e_%';

-- Réactive les triggers
SET session_replication_role = 'origin';