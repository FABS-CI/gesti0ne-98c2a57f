# Plan de Restauration du Module Colisage (Modification & Étiquettes)

Ce plan vise à corriger les deux régressions majeures du module Colisage en restaurant les comportements historiques stables (basés sur le commit `6bf3801`) : la gestion des colisages existants/modifiables et le pipeline complet des étiquettes (QR, impression, aperçu).

## Objectifs
1. Restaurer le préchargement fidèle des données lors de la consultation/modification.
2. Garantir que la modification met à jour l'existant sans duplication.
3. Sécuriser le pipeline des étiquettes (Validation -> Données -> QR -> PDF/Print) pour éviter les pages blanches.
4. Restaurer les fonctionnalités de réimpression et d'actions individuelles par étiquette.

## Étapes techniques

### 1. Données et Modification
- **Correction du préchargement** : S'assurer que `ColisageForm` initialise son état (`responsable`, `mode`, `cartons`, etc.) dès que `colisExistants` est disponible.
- **Validation de la modification** : Vérifier que `creer_colisage_manuel` (RPC) gère correctement le remplacement des anciens cartons pour éviter les doublons lors d'une mise à jour.

### 2. Pipeline des Étiquettes (Anti-Page Blanche)
- **Générateur Autonome** : Utiliser `src/lib/etiquette-html.ts` comme source unique de vérité pour générer le HTML des étiquettes. Ce générateur construit le contenu à partir des données réelles (pas de capture DOM) et convertit les ressources (logo, QR, images produits) en Data-URLs pour le PDF.
- **QR Codes Réels** : Garantir que chaque étiquette génère son propre QR Code lié à l'ID réel du colis ou aux données de secours.

### 3. Interface et Actions
- **Actions par étiquette** : Restaurer dans `EtiquettesSection` les boutons individuels [👁 Prévisualiser], [↓ Télécharger], [🖨 Imprimer] pour chaque carton.
- **Impression Globale** : Rétablir le bouton [🖨 Imprimer toutes les étiquettes].
- **Réimpression** : S'assurer que la section des étiquettes est visible pour tout colisage validé, permettant la réimpression sans recréation de données.
- **Nettoyage UI** : Supprimer toute mention de "Format de carton" si absente de l'historique.

### 4. Workflow de Validation
- **Auto-Print** : Maintenir le déclenchement automatique de l'impression après validation via `triggerAutoPrintEtiquettes`.

## Vérification
- Test de création de colisage -> Impression automatique complète.
- Test de modification d'un colisage existant -> Mise à jour sans doublons.
- Test de réimpression d'un colisage ancien -> Contenu visible et complet.
