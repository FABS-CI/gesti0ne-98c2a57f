# Formation Commercial / Secrétariat

**Public :** Commerciaux, secrétariat, assistantes. **Durée :** 5 jours.

## Jour 1 — Tronc commun
Voir `docs/formation/commun/jour1-tronc-commun.md`.

## Jour 2 — Modules métier

### 2.1 Clients (`/clients`)
- Créer : nom, type (particulier/société), téléphone, email, adresse, conditions de paiement, commercial référent.
- Vérifier **doublons** (recherche par nom/tél) avant création.
- Ne jamais modifier le code client d'un compte actif.

### 2.2 Proformas (`/proformas`)
1. Nouvelle proforma → client → lignes (produit + qté + prix).
2. Vérifier remises, TVA, total.
3. **Envoyer** (PDF).
4. Convertir en commande à l'accord client.

### 2.3 Commandes (`/commandes`)
1. Créer depuis proforma (bouton **Convertir**) ou de zéro.
2. Vérifier la disponibilité des stocks (colonne "dispo").
3. **Valider** → génère la préparation.
4. Suivre le statut : `nouvelle` → `en préparation` → `expédiée` → `livrée` → `facturée`.

**À ne jamais faire :** modifier les quantités d'une commande validée sans passer par un avenant.

### 2.4 Colisage (`/colisage`)
1. Ouvrir la commande à préparer.
2. **Ordre de colisage** → constitution des colis (produits + quantités par colis).
3. Imprimer étiquettes colis.
4. Marquer **prêt**.

### 2.5 Livraisons (`/livraisons`)
1. Créer livraison depuis commande.
2. Assigner livreur + véhicule + tournée.
3. Imprimer **bon de livraison**.
4. Suivi de tournée (`/livraisons/suivi`) → statuts en temps réel.
5. À retour livreur : **valider la livraison** avec preuve (signature/photo).

### 2.6 Facture (déclencheur par comptabilité)
- Le commercial peut consulter mais **c'est la comptabilité qui valide** la facture.
- Vérifier que la commande livrée soit bien facturée sous 48h.

### 2.7 Retours (`/retours`)
- Retour client (SAV, erreur livraison).
- Générer bon de retour + avoir si applicable.

### 2.8 KPI à vérifier après chaque étape
- Nb commandes ouvertes, montant en attente, taux de conversion proforma → commande, délai moyen commande → livraison.

## Jour 3 — Cas pratiques
1. Créer un client "Boutique Test", vérifier absence de doublon.
2. Créer une proforma 3 lignes, l'envoyer, la convertir en commande.
3. Faire le colisage, imprimer étiquettes.
4. Créer la livraison, l'assigner, imprimer BL.
5. Simuler retour du livreur + validation avec signature.
6. Consulter la fiche client : la commande apparaît en attente de facturation.

## Jour 4 — Simulation
Journée : 4 nouveaux clients, 6 proformas, 4 conversions, 3 livraisons validées, 1 retour, gestion des relances.

## Jour 5 — Évaluation
QCM `quiz.md` + exercice noté : cycle complet client → proforma → livraison validée en < 30 min.
