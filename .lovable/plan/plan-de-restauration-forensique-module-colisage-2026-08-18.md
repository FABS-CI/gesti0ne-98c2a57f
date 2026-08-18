# Plan de Restauration Forensique : Module Colisage

Restauration du module Colisage à son état opérationnel historique (base commit `6bf3801`), en supprimant les régressions récentes (`format_carton`) et en assurant la conformité du flux QR/Étiquettes.

## Étapes de Restauration

### 1. Nettoyage des Types et API
- Supprimer `format_carton` de `src/lib/colisage-api.ts` (types `ColisRow`, `CartonManuel`).
- Nettoyer `src/lib/colisage-helpers.ts` (type `EtiquettePayload`).
- Aligner `src/components/colisage/form/colisage-form-types.ts` sur la structure historique.

### 2. Interface de Saisie (ColisageForm)
- Supprimer le sélecteur "Format de carton" dans `ColisageCartonsSection.tsx`.
- Restaurer les libellés historiques ("Valider le colisage" au lieu de regénérer).
- Garantir le pré-chargement fidèle de l'état des cartons lors de la modification.

### 3. Étiquetage et Rendu
- Aligner `EtiquetteCarton.tsx` sur le design centré sans bloc "FORMAT".
- Vérifier la génération du QR code pointant vers `/carton/$id`.
- Assurer le délai de rendu de 800ms pour la stabilité des QR codes avant impression.

### 4. Impression et Mise en Page
- Restaurer les styles CSS `@media print` dans `src/styles.css` pour le format A4 Portrait (2 étiquettes par page avec repères de découpe).
- Synchroniser `EtiquettesSection.tsx` et `colisage-print-utils.ts` pour utiliser les mêmes gabarits HTML.

## Détails Techniques
- **Source de vérité** : Commit `6bf3801`.
- **Régressions éliminées** : Champ `format_carton` introduit en `be7cc27`.
- **Compatibilité** : Maintien de la route publique `/carton/$id` et de la RPC `get_carton_public`.
- **Sécurité** : Maintien des vérifications RBAC pour la modification/annulation.
