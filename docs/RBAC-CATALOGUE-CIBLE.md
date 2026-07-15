# Catalogue RBAC cible — ERP

Source de vérité pour tous les lots de la refonte Rôles & Permissions.
Généré par audit exhaustif du code (routes, boutons, RPC, mutations).

**Légende**
- ✅ Permission dédiée présente en base ET utilisée
- ⚠️ Action présente en code, permission générique (fallback rôle ou parent)
- ❌ Action présente en code, **aucune permission associée** — à créer

---

## Synthèse chiffrée

| Module | ✅ | ⚠️ | ❌ |
|---|---|---|---|
| Tableau de bord | 5 | 0 | 3 |
| Gestion commerciale | 18 | 12 | 42 |
| Stocks & Logistique | 14 | 8 | 35 |
| Finances | 5 | 4 | 8 |
| Comptabilité | 9 | 1 | 12 |
| FNE | 5 | 0 | 6 |
| Ressources Humaines | 9 | 9 | 20 |
| Paie | 5 | 0 | 10 |
| Notifications | 2 | 0 | 5 |
| Documents | 3 | 2 | 3 |
| Sauvegardes | 2 | 0 | 4 |
| Utilisateurs | 1 | 0 | 8 |
| Rôles & Permissions | 1 | 0 | 7 |
| Paramètres | 4 | 0 | 3 |
| Audit | 1 | 5 | 4 |
| Rapports | 3 | 0 | 4 |
| **TOTAL** | **87** | **41** | **174** |

**302 actions identifiées** dont 174 sans protection RBAC.

---

## Actions nouvelles à créer (Lot 3)

Voir `supabase/migrations/*_rbac_v2_permissions_metier.sql` pour l'insertion en base et l'attribution par défaut aux rôles.

### Tableau de bord
- `dashboard_direction.voir_ca` — Voir le CA sur le tableau de bord direction
- `dashboard_direction.voir_marges` — Voir les marges sur le tableau de bord direction
- `bi_analytics.exporter_excel` — Exporter les analyses BI en Excel

### Gestion commerciale — Clients
- `clients.archiver` — Archiver un client
- `clients.bloquer` — Bloquer/débloquer un client
- `clients.voir_historique` — Voir l'historique d'un client
- `clients.voir_ca` — Voir le chiffre d'affaires client
- `clients.voir_stats` — Voir les statistiques client
- `clients.exporter_excel` — Exporter les clients en Excel

### Gestion commerciale — Produits
- `produits.archiver` — Archiver un produit
- `produits.voir_prix` — Voir les prix de vente
- `produits.voir_couts` — Voir les prix d'achat / coûts
- `produits.voir_marges` — Voir les marges
- `produits.exporter_excel` — Exporter les produits en Excel
- `produits.imprimer` — Imprimer la fiche produit

### Gestion commerciale — Commandes
- `commandes.soumettre` — Soumettre une commande pour validation
- `commandes.annuler` — Annuler une commande
- `commandes.generer_proforma` — Générer une proforma depuis une commande
- `commandes.convertir_en_bl` — Convertir une commande en bon de livraison
- `commandes.generer_facture` — Générer une facture depuis une commande
- `commandes.imprimer` — Imprimer une commande
- `commandes.telecharger_pdf` — Télécharger le PDF d'une commande
- `commandes.exporter_excel` — Exporter la liste des commandes
- `commandes.voir_prix` — Voir les prix dans une commande
- `commandes.dupliquer` — Dupliquer une commande

### Gestion commerciale — Proformas
- `proformas.creer` — Créer une proforma
- `proformas.modifier` — Modifier une proforma
- `proformas.convertir_en_commande` — Convertir une proforma en commande
- `proformas.imprimer` — Imprimer une proforma
- `proformas.telecharger_pdf` — Télécharger le PDF d'une proforma

### Gestion commerciale — Factures
- `factures.creer` — Créer une facture
- `factures.modifier` — Modifier une facture
- `factures.soumettre_fne` — Soumettre une facture au FNE
- `factures.annuler` — Annuler une facture
- `factures.exporter_excel` — Exporter les factures en Excel
- `factures.exporter_pdf` — Exporter les factures en PDF
- `factures.imprimer` — Imprimer une facture
- `factures.voir_prix` — Voir les montants d'une facture

### Gestion commerciale — Bons de livraison / Colisage
- `bons_livraison.creer` — Créer un bon de livraison
- `bons_livraison.imprimer` — Imprimer un BL
- `bons_livraison.telecharger_pdf` — Télécharger le PDF d'un BL
- `colisage.modifier` — Modifier un colisage
- `colisage.deverrouiller` — Déverrouiller un colisage
- `colisage.imprimer_etiquettes` — Imprimer les étiquettes de colis
- `colisage_responsables.voir` — Gérer les responsables colisage

### Gestion commerciale — Retours / Spécimens / Expéditions
- `retours.creer` — Créer un retour
- `retours.imprimer` — Imprimer un retour
- `specimens.creer` — Créer un spécimen
- `specimens.imprimer` — Imprimer un spécimen
- `expeditions.creer` — Créer une expédition

### Gestion commerciale — État de compte clients
- `etat_compte_clients.exporter_pdf` — Exporter l'état de compte en PDF
- `etat_compte_clients.recalculer` — Recalculer le solde d'un client

### Stocks & Logistique — Stock
- `stock.creer_mouvement` — Créer un mouvement de stock manuel
- `stock.recalculer` — Recalculer le stock (global ou produit)
- `stock.exporter_excel` — Exporter le stock en Excel
- `stock.voir_audit` — Voir l'audit du stock
- `stock.voir_mouvements` — Voir les mouvements d'un produit
- `alertes_stock.voir` — Voir les alertes de stock (dédiée)

### Stocks & Logistique — Dépôts
- `depots.creer` — Créer un dépôt
- `depots.modifier` — Modifier un dépôt
- `depots.definir_principal` — Définir le dépôt principal

### Stocks & Logistique — Transferts
- `transferts.creer` — Créer un transfert
- `transferts.executer` — Exécuter un transfert
- `transferts.receptionner` — Réceptionner un transfert
- `transferts.imprimer` — Imprimer un transfert
- `transferts.telecharger_pdf` — Télécharger le PDF d'un transfert

### Stocks & Logistique — Inventaires
- `inventaires.creer` — Créer un inventaire
- `inventaires.regulariser` — Régulariser un inventaire
- `inventaires.exporter_excel` — Exporter un inventaire en Excel

### Stocks & Logistique — Fournisseurs / Achats
- `fournisseurs.creer` — Créer un fournisseur
- `fournisseurs.modifier` — Modifier un fournisseur
- `achats.creer` — Créer un achat
- `achats.receptionner` — Réceptionner un achat
- `achats.payer` — Payer un achat
- `achats.imprimer` — Imprimer un achat

### Stocks & Logistique — Incidents
- `incidents.creer` — Créer un incident
- `incidents.modifier` — Modifier un incident
- `incidents.imprimer` — Imprimer un incident

### Stocks & Logistique — Tournées / Livraisons
- `tournees.creer` — Créer une tournée
- `tournees.cloturer` — Clôturer une tournée
- `tournees.valider_couts` — Valider les coûts d'une tournée
- `tournees.refuser_couts` — Refuser les coûts d'une tournée
- `tournees.annuler_validation` — Annuler la validation d'une tournée
- `tournees.imprimer` — Imprimer une tournée
- `livraisons.avancer_etape` — Faire avancer une étape de livraison
- `livraisons.avancer_masse` — Faire avancer en masse
- `livraisons.valider_remise` — Valider une remise de livraison
- `livraisons.imprimer` — Imprimer une livraison
- `couts_logistiques.creer` — Saisir des coûts logistiques
- `couts_logistiques.valider` — Valider des coûts logistiques
- `couts_logistiques.exporter_pdf` — Exporter les coûts logistiques

### Stocks & Logistique — Flotte
- `flotte.creer` — Créer un véhicule / livreur
- `flotte.modifier` — Modifier un véhicule / livreur
- `flotte.supprimer` — Supprimer un véhicule / livreur

### Finances
- `paiements.creer` — Enregistrer un paiement
- `paiements.rejeter` — Rejeter un paiement
- `paiements.exporter_excel` — Exporter les paiements
- `paiements.imprimer_recu` — Imprimer un reçu de paiement
- `paiements.voir_historique_annulations` — Voir l'historique des annulations
- `finances.creer` — Créer une transaction
- `finances.modifier` — Modifier une transaction
- `finances.exporter_excel` — Exporter les transactions
- `finances.voir_ca` — Voir les KPI trésorerie

### Comptabilité
- `comptabilite.exporter_excel` — Exporter des données comptables en Excel
- `comptabilite.exporter_pdf` — Exporter des données comptables en PDF
- `ecritures_comptables.creer` — Créer une écriture
- `ecritures_comptables.modifier` — Modifier une écriture
- `ecritures_comptables.supprimer` — Supprimer une écriture
- `plan_comptable.creer` — Ajouter un compte au plan comptable
- `plan_comptable.modifier` — Modifier un compte du plan comptable
- `balance.exporter_excel` — Exporter la balance
- `grand_livre.exporter_excel` — Exporter le grand livre
- `fec.generer` — Générer le FEC
- `fec.telecharger` — Télécharger le FEC
- `exercices.cloturer` — Clôturer un exercice
- `exercices.modifier` — Modifier un exercice

### FNE
- `fne.soumettre` — Soumettre une facture au FNE
- `fne.reessayer` — Réessayer un envoi FNE
- `fne.rembourser` — Rembourser via le FNE
- `fne.imprimer` — Imprimer un document FNE
- `fne.telecharger_json` — Télécharger le JSON FNE
- `fne.modifier_parametres` — Modifier les paramètres FNE

### Ressources Humaines
- `employes.creer` — Créer un employé
- `employes.modifier` — Modifier un employé
- `employes.restaurer` — Restaurer un employé archivé
- `employes.renumeroter` — Renuméroter les matricules
- `employes.exporter_excel` — Exporter les employés
- `employes.imprimer_fiche` — Imprimer la fiche employé
- `employes.creer_compte` — Créer un compte utilisateur pour un employé
- `departements.creer` — Créer un département
- `departements.modifier` — Modifier un département
- `departements.supprimer` — Supprimer un département
- `fonctions.creer` — Créer une fonction
- `fonctions.modifier` — Modifier une fonction
- `fonctions.supprimer` — Supprimer une fonction
- `contrats.creer` — Créer un contrat
- `contrats.modifier` — Modifier un contrat
- `contrats.supprimer` — Supprimer un contrat
- `contrats.imprimer` — Imprimer un contrat
- `conges.creer` — Créer un congé
- `conges.modifier` — Modifier un congé
- `conges.approuver` — Approuver un congé
- `conges.rejeter` — Rejeter un congé
- `absences.creer` — Créer une absence
- `absences.modifier` — Modifier une absence
- `absences.supprimer` — Supprimer une absence
- `missions.creer` — Créer une mission
- `missions.modifier` — Modifier une mission
- `missions.supprimer` — Supprimer une mission
- `evaluations.creer` — Créer une évaluation
- `evaluations.modifier` — Modifier une évaluation
- `evaluations.supprimer` — Supprimer une évaluation

### Paie
- `paie.creer_bulletin` — Créer un bulletin
- `paie.modifier_bulletin` — Modifier un bulletin
- `paie.supprimer_bulletin` — Supprimer un bulletin
- `paie.imprimer_bulletin` — Imprimer un bulletin
- `paie_rubriques.creer` — Créer une rubrique de paie
- `paie_rubriques.modifier` — Modifier une rubrique de paie
- `paie_rubriques.supprimer` — Supprimer une rubrique de paie
- `paie.declarer_cnps` — Déclarer la CNPS
- `paie.declarer_fdfp` — Déclarer le FDFP
- `paie.declarer_its` — Déclarer l'ITS
- `paie.telecharger_declaration` — Télécharger une déclaration

### Notifications
- `notifications.marquer_lue` — Marquer une notification comme lue
- `notifications.supprimer` — Supprimer une notification
- `notifications.purger` — Purger les notifications
- `notifications.generer` — Générer des notifications
- `notifications.exporter_historique` — Exporter l'historique

### Documents
- `documents.telecharger` — Télécharger un document
- `modeles_documents.creer` — Créer un modèle
- `modeles_documents.modifier` — Modifier un modèle
- `modeles_documents.imprimer` — Aperçu / impression modèle

### Sauvegardes
- `backup.creer` — Lancer une sauvegarde
- `backup.exporter_csv` — Exporter en CSV
- `backup.planifier` — Planifier une sauvegarde
- `backup.restaurer` — Restaurer une sauvegarde

### Administration — Utilisateurs
- `utilisateurs.creer` — Créer un utilisateur
- `utilisateurs.modifier` — Modifier un utilisateur
- `utilisateurs.activer_desactiver` — Activer / désactiver un utilisateur
- `utilisateurs.assigner_role` — Assigner un rôle
- `utilisateurs.revoquer_role` — Révoquer un rôle
- `utilisateurs.reset_mfa` — Réinitialiser le MFA d'un utilisateur
- `utilisateurs.revoquer_mfa` — Révoquer le MFA d'un utilisateur

### Rôles & Permissions
- `roles_permissions.creer_role` — Créer un rôle
- `roles_permissions.modifier_role` — Modifier un rôle
- `roles_permissions.supprimer_role` — Supprimer un rôle
- `roles_permissions.dupliquer_role` — Dupliquer un rôle
- `roles_permissions.assigner_permission` — Modifier les permissions d'un rôle
- `roles_permissions.assigner_role_utilisateur` — Assigner un rôle à un utilisateur
- `roles_permissions.voir_audit` — Voir l'audit RBAC

### Paramètres
- `parametres.modifier` — Modifier les paramètres système

### Audit
- `audit.exporter` — Exporter le journal d'audit
- `audit.recalculer_soldes` — Recalculer les soldes clients globaux

### Rapports
- `rapports.voir_ca` — Voir le CA dans les rapports
- `rapports.voir_marges` — Voir les marges dans les rapports
- `rapports.exporter_excel` — Exporter les rapports en Excel
- `rapports.exporter_pdf` — Exporter les rapports en PDF

