
-- =========================================================================
-- Purge des données transactionnelles de test (avant mise en production).
-- TRUNCATE ... RESTART IDENTITY CASCADE : nettoie et réinitialise les
-- séquences internes des colonnes SERIAL/IDENTITY de ces tables.
-- =========================================================================

TRUNCATE TABLE
  -- Cycle de vente
  public.proforma_lignes,
  public.proformas,
  public.commande_lignes,
  public.commandes,
  public.bons_livraison,
  public.factures,
  public.paiements,
  public.paiement_annulations_audit,
  -- Comptabilité
  public.ecriture_lignes,
  public.ecritures_comptables,
  public.transactions,
  -- Achats
  public.achat_lignes,
  public.achats,
  -- Retours
  public.retour_lignes,
  public.retours,
  public.bons_retour,
  -- Incidents
  public.incident_lignes,
  public.incidents,
  public.incident_alerts,
  -- Colisage / Tournées / Livraisons
  public.colis_lignes,
  public.colis_statut_historique,
  public.colisage_modifications_historique,
  public.colis,
  public.ordres_colisage,
  public.tournees,
  public.livsuivi_historique,
  public.livsuivi_commandes,
  public.livsuivi_tournees,
  public.livraison_commande_historique,
  public.livraisons_commande,
  public.livraisons,
  public.expeditions,
  public.couts_logistiques_audit,
  -- Stock
  public.stock_mouvements,
  public.transfert_lignes,
  public.transferts,
  public.inventaire_lignes,
  public.inventaires,
  public.specimen_lignes,
  public.specimens,
  -- FNE
  public.fne_logs,
  public.fne_factures,
  -- Notifications / audit / logs
  public.notifications,
  public.notifications_purge_log,
  public.audit_events,
  public.audit_logs,
  public.rbac_audit_log,
  public.trigger_execution_log,
  public.perf_query_log,
  public.historique_envois,
  public.login_history,
  -- Workflows / fidélité
  public.workflow_approvals,
  public.client_fidelite_mouvements
RESTART IDENTITY CASCADE;

-- =========================================================================
-- Réinitialisation explicite des séquences de numérotation des documents.
-- Les prochaines créations démarreront à 1.
-- Les séquences des données de référence (clients_ref_seq, produit_ref_seq,
-- employe_ref_seq) sont volontairement PRÉSERVÉES.
-- =========================================================================

ALTER SEQUENCE public.proformas_ref_seq       RESTART WITH 1;
ALTER SEQUENCE public.commande_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.bons_livraison_ref_seq  RESTART WITH 1;
ALTER SEQUENCE public.factures_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.paiements_ref_seq       RESTART WITH 1;
ALTER SEQUENCE public.ecriture_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.achat_ref_seq           RESTART WITH 1;
ALTER SEQUENCE public.bons_retour_ref_seq     RESTART WITH 1;
ALTER SEQUENCE public.colis_ref_seq           RESTART WITH 1;
ALTER SEQUENCE public.couts_ref_seq           RESTART WITH 1;
ALTER SEQUENCE public.fne_ref_seq             RESTART WITH 1;
ALTER SEQUENCE public.incidents_ref_seq       RESTART WITH 1;
ALTER SEQUENCE public.inventaires_ref_seq     RESTART WITH 1;
ALTER SEQUENCE public.livraisons_ref_seq      RESTART WITH 1;
ALTER SEQUENCE public.retours_ref_seq         RESTART WITH 1;
ALTER SEQUENCE public.transaction_ref_seq     RESTART WITH 1;
ALTER SEQUENCE public.workflow_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.missions_ref_seq        RESTART WITH 1;
ALTER SEQUENCE public.audit_events_seq_seq    RESTART WITH 1;
