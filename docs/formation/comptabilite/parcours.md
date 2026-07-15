# Formation Comptabilité — Facturation → Paiements → Comptes clients

**Public :** Comptable, DG (lecture), Super Admin. **Durée :** 5 jours.

## Jour 1 — Tronc commun
Voir `docs/formation/commun/jour1-tronc-commun.md`.

## Jour 2 — Modules métier

### 2.1 Factures (`/factures`)
**Rôle du module :** émettre, suivre et clôturer les factures clients.
**Quand l'utiliser :** après validation d'une commande / livraison, ou pour une vente directe.
**Ordre des opérations :**
1. `Nouvelle facture` → sélectionner **client existant** (jamais un libellé libre).
2. Rattacher la commande d'origine si applicable (montant recalculé automatiquement).
3. Vérifier date facture, date échéance, exercice.
4. **Valider** — la facture devient officielle : numéro `FAC-xxxxx` figé.

**Contrôles obligatoires :** total TTC, échéance cohérente avec conditions client, exercice comptable actif.
**Bonnes pratiques :** ne jamais modifier une facture validée — émettre un avoir. Vérifier l'aperçu PDF avant validation.
**Erreurs fréquentes :**
- Facture émise sur mauvais client → **avoir + refacturation**.
- Montant erroné (remise oubliée) → avoir partiel.
- Facture sur exercice clôturé → **impossible** (blocage automatique).

### 2.2 Enregistrer un paiement (`/paiements/nouveau`)
**Rôle :** saisir un encaissement et l'imputer à une facture.
**Prérequis :** facture au statut `impayee` ou `partielle`.
**Étapes détaillées :**
1. Sélectionner le client → la liste des factures dues s'affiche.
2. Cocher la ou les factures à imputer.
3. Saisir : **montant reçu, mode (espèces / virement / chèque / mobile money), référence (obligatoire), date**.
4. Vérifier le **récapitulatif** : reste avant → montant imputé → reste après.
5. **Valider**.

**Contrôles automatiques (défense en profondeur) :**
- Montant > 0.
- Montant ≤ solde restant (rejet en base sinon).
- Référence non vide.

**Impact :**
- `factures.montant_paye` augmente, statut recalculé (`impayee` → `partielle` → `payee`).
- KPI client (encaisse, solde dû, taux de recouvrement) recalculés immédiatement.
- Notification envoyée au commercial du client.

**À ne jamais faire :** ressaisir un paiement déjà enregistré (doublon), imputer sur la mauvaise facture, saisir un montant supérieur au solde.

### 2.3 Annuler un paiement (`/paiements/:id`)
**Autorisation :** Super Admin, DG, Comptable uniquement.
**Étapes :**
1. Ouvrir le paiement.
2. Cliquer **Annuler**.
3. **Saisir la raison (obligatoire)** + notes.
4. Confirmer.

**Impact :**
- Paiement passe au statut `annule` avec horodatage.
- `factures.montant_paye` diminué du montant annulé, statut recalculé.
- Ligne écrite dans **journal d'audit** (`/admin/audit-paiements`) : qui, quand, raison, montant, facture.

**Ce qu'il ne faut jamais faire :** annuler sans raison écrite (impossible), annuler un paiement déjà annulé, "compenser" en créant un paiement négatif.

### 2.4 Fiche client (`/clients/:id`)
- Onglet **Paiements** : historique paginé (10/25/50), tri par date/référence/mode/statut/montant, recherche par référence.
- Onglet **Factures** : détail statuts, retards.
- **KPI :** total facturé, total encaissé, solde dû, taux de recouvrement, factures ouvertes.
- Vérifier ces KPI après chaque opération.

### 2.5 Comparatif multi-exercices (`/exercices/comparatif`)
- Colonnes : CA, encaissé, achats, résultat, % évolution.
- **Export PDF** contient les mêmes exercices, tri et % que l'écran (horodatage + utilisateur inclus).
- Filtres et tri persistés en localStorage.

## Jour 3 — Cas pratiques
1. Créer une facture 500 000 XOF pour un client existant, valider, imprimer.
2. Encaisser 200 000 XOF → vérifier statut `partielle` et KPI client.
3. Encaisser le solde → statut `payee`.
4. Annuler le second paiement avec raison "erreur d'imputation" → vérifier journal d'audit et KPI recalculés.
5. Exporter le comparatif d'exercice en PDF, vérifier horodatage + utilisateur.

## Jour 4 — Simulation d'une journée
Traiter la file du jour : 5 nouvelles factures, 8 encaissements (dont 1 sur-paiement tenté → doit être rejeté), 1 annulation avec audit, clôture avec vérification des KPI et rapprochement caisse.

## Jour 5 — Évaluation
- QCM (voir `quiz.md`).
- Exercice pratique noté par le formateur : cycle complet facture → paiement → annulation → audit.
- Critère de réussite : 0 erreur d'imputation, journal d'audit conforme, KPI cohérents.
