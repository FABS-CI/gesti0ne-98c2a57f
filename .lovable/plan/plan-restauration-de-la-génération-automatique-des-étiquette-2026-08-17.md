# Plan : Restauration de la génération automatique des étiquettes de colisage

Le but est de restaurer l'impression automatique des étiquettes dès la validation du colisage (lorsque le statut passe à `colisage_termine`). Cette fonctionnalité a disparu suite aux refontes des composants de formulaire.

## Modifications

### 1. Composant `ColisageForm` (`src/components/colisage/ColisageForm.tsx`)
- Ajouter un état `justFinished` (boolean) pour suivre la réussite d'une validation.
- Dans le callback `onSuccess` de la mutation `creerColisageManuel` :
    - Activer `justFinished(true)`.
- Ajouter un `useEffect` qui surveille `justFinished` et les étiquettes disponibles :
    - Si `justFinished` est vrai et que des étiquettes sont présentes (via le payload construit), déclencher l'impression via `printEtiquettes`.
    - Réinitialiser `justFinished` après l'action.

### 2. Route `ColisageDetailPage` (`src/routes/_authenticated/colisage.$blId.tsx`)
- Passer une nouvelle prop `onSuccess` au composant `ColisageForm` (optionnel, mais propre pour la coordination).
- S'assurer que les données de colis (`colisExistants`) sont rafraîchies immédiatement après la mutation pour que le payload des étiquettes soit à jour au moment de l'impression.

## Détails techniques
- La fonction `printEtiquettes` est déjà présente dans `src/lib/print-etiquettes.ts`.
- La logique de génération du HTML des étiquettes sera extraite ou réutilisée depuis `EtiquettesSection.tsx` pour garantir la cohérence visuelle demandée ("ne pas réinventer").

## Évaluation des risques
- Aucun risque de perte de données (lecture seule pour l'impression).
- Vérifier que le blocage des pop-ups ne casse pas l'expérience (déjà géré par un toast dans `printEtiquettes`).
