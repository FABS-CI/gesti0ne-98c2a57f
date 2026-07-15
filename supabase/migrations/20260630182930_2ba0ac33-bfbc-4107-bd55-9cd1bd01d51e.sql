
-- Réinitialisation des données commerciales (atomique)
-- Stock, clients, fournisseurs, produits, utilisateurs, paramètres : PRÉSERVÉS

TRUNCATE TABLE
  public.commande_lignes,
  public.commandes,
  public.bons_livraison,
  public.bons_retour,
  public.factures,
  public.paiements,
  public.proforma_lignes,
  public.proformas,
  public.retour_lignes,
  public.retours,
  public.colis_statut_historique,
  public.colis,
  public.ordres_colisage,
  public.expeditions,
  public.historique_envois,
  public.livraison_commande_historique,
  public.livraisons_commande,
  public.livraisons,
  public.tournees,
  public.couts_logistiques,
  public.transactions,
  public.fne_logs,
  public.fne_factures,
  public.ecriture_lignes,
  public.ecritures_comptables,
  public.documents
RESTART IDENTITY CASCADE;

-- Trace audit
INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, new_values)
VALUES (NULL, 'system', 'reset_commercial_data', 'multiple', 'reset-' || to_char(now(),'YYYYMMDD-HH24MISS'),
  jsonb_build_object(
    'description', 'Réinitialisation complète des données commerciales avant mise en production',
    'preserved', jsonb_build_array('clients','fournisseurs','produits','stocks_depots','stock_mouvements','depots','inventaires','user_roles','profiles','employes','parametres','fne_settings'),
    'timestamp', now()
  ));
