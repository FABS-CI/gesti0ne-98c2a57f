# Formation Stock — Gestionnaire de stock / Magasinier

**Public :** Responsable magasin, magasinier, gestionnaire de stock. **Durée :** 5 jours.

## Jour 1 — Tronc commun
Voir `docs/formation/commun/jour1-tronc-commun.md`.

## Jour 2 — Modules métier

### 2.1 Produits (`/produits`)
- Consulter fiche produit : référence, catégorie, unité, seuil d'alerte, stocks par dépôt.
- Ne jamais dupliquer un article — vérifier avant création.

### 2.2 Réception d'achat (`/achats/:id` → Réceptionner)
**Prérequis :** bon d'achat validé.
**Étapes :**
1. Ouvrir l'achat.
2. Cliquer **Réceptionner**.
3. Pour chaque ligne : saisir la quantité **réellement reçue** (peut être < quantité commandée).
4. Vérifier état / lot / DLC si applicable.
5. Valider → génère un **bon de livraison fournisseur** et un mouvement de stock **entrée**.

**Contrôles :** quantité reçue ≤ quantité commandée, N° BL fournisseur, signature réceptionnaire.
**À ne jamais faire :** réceptionner sans vérification physique, saisir la quantité commandée sans compter.

### 2.3 Mouvements de stock (`/stock/mouvements`)
- Types : **entrée** (réception, retour client), **sortie** (livraison, casse), **transfert**, **ajustement**.
- Chaque mouvement est horodaté et attribué à l'utilisateur.
- **Consultation uniquement** — les mouvements naissent des opérations métier (réception, livraison, inventaire).

### 2.4 Transferts inter-dépôts (`/transferts`)
1. Créer un transfert → dépôt source + dépôt destination.
2. Ajouter les lignes (produits + quantités).
3. **Expédier** (sortie du dépôt source).
4. **Réceptionner** (entrée au dépôt destination) — obligatoire pour clôturer.

**Erreur fréquente :** transfert expédié jamais réceptionné → stock "en transit" fantôme. Contrôle hebdo obligatoire.

### 2.5 Inventaire (`/inventaires`)
1. Créer un inventaire (dépôt, date, type : partiel/total).
2. Imprimer la feuille de comptage.
3. Compter physiquement, saisir les quantités.
4. Comparer théorique vs compté → écarts affichés.
5. **Valider** → génère un **ajustement** automatique (entrée ou sortie par ligne).

**À ne jamais faire :** valider un inventaire sans double-comptage des écarts > seuil.

### 2.6 Ajustements manuels
- Réservés aux cas exceptionnels (casse constatée, vol).
- Motif obligatoire, validation Super Admin.

### 2.7 Rapports stock
- **Stock actuel par dépôt** : `/rapports/stock`.
- **Rotation** : produits sans mouvement > 90 j.
- **Ruptures / seuils d'alerte** : liste rouge.
- **KPI stock à vérifier après chaque étape :** valeur totale, nb ruptures, écart inventaire (%).

## Jour 3 — Cas pratiques
1. Réceptionner une commande fournisseur avec 1 écart de quantité.
2. Créer un transfert Dépôt A → Dépôt B, expédier, réceptionner.
3. Lancer un inventaire partiel, saisir des écarts, valider.
4. Créer un ajustement de casse (5 unités) avec motif.
5. Consulter les rapports et comparer avec la veille.

## Jour 4 — Simulation
Journée type : 3 réceptions, 5 sorties livraison, 1 transfert, 2 ajustements, contrôle des seuils d'alerte, clôture caisse stock.

## Jour 5 — Évaluation
QCM `quiz.md` + inventaire complet d'un dépôt de test avec ≤ 2 écarts non justifiés.
