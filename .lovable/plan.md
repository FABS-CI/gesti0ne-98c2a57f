# Plan de Restauration de l'UI de Colisage et Étiquetage

Restauration de la visibilité et du fonctionnement des actions d'étiquetage (individuelles et globales) et de l'Auto-Print après validation.

## 1. Visibilité des Actions Individuelles
- Modifier `src/components/colisage/EtiquettesSection.tsx` pour s'assurer que les boutons [👁 Aperçu], [↓ Télécharger], [🖨 Imprimer], [🔗 Tracking] sont rendus sans ambiguïté.
- Vérifier les styles Tailwind/CSS pour éviter tout masquage accidentel (overflow, display:none).
- Garantir que chaque bouton cible le bon `colis_id`.

## 2. Actions Globales
- Confirmer la présence du bouton [🖨 Imprimer tout] dans le header de `EtiquettesSection`.
- S'assurer que le format A4 Portrait avec 2 étiquettes par page est respecté via `src/lib/etiquette-html.ts`.

## 3. Workflow Auto-Print
- Vérifier le déclenchement dans `src/routes/_authenticated/colisage.$blId.tsx` au sein du callback `onSuccess` du `ColisageForm`.
- S'assurer que `triggerAutoPrintEtiquettes` (dans `src/lib/colisage-print-utils.ts`) utilise bien le HTML complet généré.

## 4. Vérification et Test
- Validation manuelle via script Playwright pour confirmer la présence des éléments dans le DOM.
- Vérification du déclenchement de la fenêtre d'impression après validation simulée.

## Détails techniques
- Utilisation de `printEtiquettes` avec le paramètre `a4-portrait-auto`.
- Maintien de l'indépendance du DOM via le générateur HTML autonome.
