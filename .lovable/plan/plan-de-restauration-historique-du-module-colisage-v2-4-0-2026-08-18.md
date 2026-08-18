# Plan de Restauration Historique du Module Colisage (v2.4.0)

Ce plan vise à restaurer le fonctionnement exact du module Colisage tel qu'il était dans sa version stable (commit 6bf3801), tout en conservant les améliorations de workflow nécessaires (modification et impression automatique).

## Audit et Constats
- Le champ `format_carton` (NC4, NC2, etc.) est une régression récente et doit être supprimé.
- La logique de répartition des articles doit être strictement alignée sur le commit 6bf3801 pour garantir l'intégrité des données.
- Le flux de modification (chargement de l'état existant) est une fonctionnalité ajoutée après 6bf3801 mais demandée par l'utilisateur, elle sera donc préservée et fiabilisée.

## Actions à réaliser

### 1. Alignement des Structures de Données
- Nettoyer `src/components/colisage/form/colisage-form-types.ts` pour retirer `format`.
- Mettre à jour `src/lib/colisage-api.ts` pour supprimer `format_carton` des types `ColisRow` et `CartonManuel`.
- Mettre à jour `src/lib/colisage-helpers.ts` pour retirer le mapping du format dans `buildEtiquettesPayload`.

### 2. Nettoyage de l'Interface (UI)
- Retirer le sélecteur de format dans `src/components/colisage/form/ColisageCartonsSection.tsx`.
- Retirer l'affichage du format sur l'étiquette dans `src/components/colisage/EtiquetteCarton.tsx`.
- S'assurer que les boutons d'action (Ajouter/Retirer carton/article) correspondent à l'ergonomie historique.

### 3. Fiabilisation de la Logique de Modification
- Dans `ColisageForm.tsx`, s'assurer que le `useEffect` d'initialisation reconstruit fidèlement les cartons à partir de `colisExistants`.
- Vérifier que la soumission regroupe correctement les lignes par `produit_id` pour le RPC `creer_colisage_manuel`.

### 4. Validation de l'Impression
- Maintenir le délai de 800ms dans `src/lib/colisage-print-utils.ts` pour garantir la capture des QR codes.
- Vérifier que le rendu A4 Portrait respecte les 2 étiquettes par page avec repères de découpe.

## Détails techniques
Les changements seront effectués par remplacement ciblé de lignes pour minimiser les risques de régression collatérale. Chaque fichier sera vérifié par rapport aux extraits du commit 6bf3801.
