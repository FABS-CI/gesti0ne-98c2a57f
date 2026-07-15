-- Pass C: nettoyage des résidus transactionnels test + init stocks 1000 sur tous dépôts actifs
-- Conserve: clients, produits, depots, employes, paramètres, FNE settings, templates, roles

-- 1. Vider résidus transactionnels test (pas de parents valides)
TRUNCATE TABLE
  public.colis_statut_historique,
  public.colis,
  public.ordres_colisage,
  public.expeditions,
  public.livraisons,
  public.bons_livraison,
  public.paiements,
  public.factures,
  public.proforma_lignes,
  public.proformas,
  public.commande_lignes,
  public.commandes,
  public.retour_lignes,
  public.retours,
  public.bons_retour,
  public.specimen_lignes,
  public.specimens,
  public.incident_lignes,
  public.incidents,
  public.inventaire_lignes,
  public.inventaires,
  public.transfert_lignes,
  public.transferts,
  public.stock_mouvements,
  public.fne_logs,
  public.fne_factures,
  public.historique_envois,
  public.documents
RESTART IDENTITY CASCADE;

-- 2. Reset stocks: produits actifs => stock=1000, seuil_alerte=100
UPDATE public.produits SET stock = 1000, seuil_alerte = 100 WHERE actif = true;

-- 3. Réinitialiser stocks_depots: 1000 par produit actif × dépôt actif
DELETE FROM public.stocks_depots;
INSERT INTO public.stocks_depots (produit_id, depot_id, quantite)
SELECT p.produit_id, d.depot_id, 1000
FROM public.produits p
CROSS JOIN public.depots d
WHERE p.actif = true AND d.actif = true;