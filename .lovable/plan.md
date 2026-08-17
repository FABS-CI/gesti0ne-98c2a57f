# Plan de Restauration du Module Colisage (Commit 6bf3801)

Restauration du module Colisage à son état fonctionnel historique en se basant sur le commit `6bf3801`, tout en conservant les améliorations de stabilité récentes.

## Changements à effectuer

### 1. Composant ColisageForm (`src/components/colisage/ColisageForm.tsx`)
- **Initialisation de l'état** : Restaurer le `useEffect` qui peuple l'état `cartons` à partir de `colisExistants`. Cela permet de voir la composition des cartons déjà validés lorsqu'on rouvre un colisage.
- **Callback de succès** : S'assurer que `onSuccess` est appelé après la création pour permettre l'impression automatique des étiquettes.
- **Nettoyage** : Supprimer les champs obsolètes (Livreur, Véhicule) qui ont été déplacés dans le module Tournées.

### 2. Route de Détail Colisage (`src/routes/_authenticated/colisage.$blId.tsx`)
- **Rendu permanent du formulaire** : S'assurer que `ColisageForm` est rendu même si `hasColis` est vrai, pour permettre la consultation et la modification (si autorisé).
- **Impression automatique** : Réactiver l'appel à `triggerAutoPrintEtiquettes` dans le callback `onSuccess`.

### 3. Utilitaires d'Impression (`src/lib/colisage-print-utils.ts`)
- **Synchronisation DOM** : S'assurer que le délai avant impression (500ms) est maintenu pour permettre au DOM de générer les QR codes avant la capture HTML.

### 4. Rappel Technique
- Les étiquettes sont générées à partir des tables `colis` et `colis_lignes`.
- Le scan des QR codes redirige vers `/carton/$id` (public).
- La recherche globale indexe les références `COL-XXXXX`.

## Vérification
1. Ouvrir un colisage existant : les cartons et leur contenu doivent s'afficher dans le formulaire.
2. Valider un colisage : une fenêtre d'impression doit s'ouvrir automatiquement avec les étiquettes.
3. Scanner (ou simuler le scan via recherche globale) : la recherche doit trouver le carton et mener au BL correspondant.
