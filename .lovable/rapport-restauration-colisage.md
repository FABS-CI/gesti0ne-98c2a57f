# Rapport de Restauration du Workflow Colisage

## 1. Dernier commit fonctionnel
**Hash :** `6bf380161c813fa0e81e740184b923d51f7bb766`

## 2. Commit de régression
**Hash :** `9cbd8daecf8c72634f1070797e67944242fe09d3` (et `be7cc27` pour `format_carton`)

## 3. Fichier responsable
`src/routes/_authenticated/colisage.$blId.tsx`

## 4. Fonction / Logique responsable
La condition de rendu `{modifiable && <ColisageForm ... />}` a été introduite, ce qui masquait le formulaire une fois le colisage validé (statut passé à `colisage_termine`). De plus, le callback `onSuccess` déclenchant l'impression automatique avait été supprimé.

## 5. Ce qui a disparu (Explication technique)
- **Déclenchement automatique :** La fonction `triggerAutoPrintEtiquettes` n'était plus appelée après la mutation réussie.
- **Persistance de l'état :** Le formulaire était démonté après validation, empêchant la consultation des données saisies et le déclenchement des effets secondaires post-validation.
- **Injection des données :** Le prop `colisExistants` n'était plus passé au formulaire, empêchant la reconstruction des cartons.

## 6. Ancien Workflow (Restauré)
1. **Validation** (`handleSubmit` -> `mutation.mutate`)
2. **Succès API** (`onSuccess`)
3. **Appel `triggerAutoPrintEtiquettes`**
4. **Invalidation Cache** (`invalidateColisage`)
5. **Affichage Immédiat** (Le formulaire reste monté et affiche les étiquettes via `EtiquettesSection`)

## 7. Nouveau Workflow (Avant correction)
1. **Validation**
2. **Succès API**
3. **Démontage du composant** (car `modifiable` devient false)
4. **Disparition de l'interface de travail**
5. **Aucun affichage automatique des étiquettes**

## 8. Correction effectuée
- Restauration du rendu permanent de `ColisageForm` dans `src/routes/_authenticated/colisage.$blId.tsx`.
- Rétablissement du callback `onSuccess` pour l'impression automatique.
- Ré-injection des `colisExistants` pour permettre la modification/consultation.
- Renommage du titre en "Modifier le colisage" pour plus de clarté.
- Suppression définitive de toute trace de `format_carton` (NC4, etc.) qui était une régression identifiée.

## 9. Fichiers modifiés
- `src/routes/_authenticated/colisage.$blId.tsx`
- `src/components/colisage/ColisageForm.tsx`

## 10. Tests
- Vérification de la chaîne de mutation : OK.
- Vérification de la logique de rendu conditionnel : OK.
- Vérification de l'absence de `format_carton` dans le DOM : OK.
