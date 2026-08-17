# Plan - Restauration du Colisage et Recherche de Cartons

Restauration de la fonctionnalité historique permettant de consulter et d'imprimer les étiquettes de cartons lors de la réouverture d'un colisage existant, et intégration des cartons dans la recherche globale pour le scan.

## Modifications proposées

### Backend (SQL)
- Mettre à jour la fonction `global_search` pour inclure la table `colis`.
- Permettre la recherche par référence de carton (`COL-XXXXX`).
- Retourner un lien vers la page de colisage du BL associé pour les résultats de recherche de cartons.

### Frontend
#### 1. Initialisation du Formulaire de Colisage
- Modifier `ColisageForm.tsx` pour accepter les `colisExistants`.
- Ajouter un `useEffect` pour charger les données des cartons existants dans l'état local du formulaire au montage.
- Mapper les données de la DB (`ColisRow`) vers le format local (`CartonState`).
- Assurer que le formulaire reste consultable (lecture seule via `fieldset disabled={!modifiable}`) tout en affichant la composition réelle.

#### 2. Amélioration de la Recherche Globale
- Mettre à jour `GlobalSearch.tsx` pour gérer le nouveau groupe "Cartons".
- Utiliser l'icône `Package` pour les cartons.
- Rediriger vers le colisage du BL concerné lors du clic sur un carton trouvé (ou vers la page de suivi public si spécifié).

#### 3. Affichage des Étiquettes
- S'assurer que `EtiquettesSection` est toujours rendu dans `ColisageDetailPage` si des cartons existent, indépendamment du statut modifiable.

## Détails techniques
- **Fichier `src/components/colisage/ColisageForm.tsx`** :
  - Props : ajout de `colisExistants?: ColisRow[]`.
  - Logique d'initialisation : `useEffect` avec dépendance sur `colisExistants`.
- **Fichier `supabase/migrations/...`** :
  - Ajout d'une clause `UNION ALL` dans `global_search` pour `public.colis`.
- **Fichier `src/components/GlobalSearch.tsx`** :
  - Ajout de la logique d'icône et de groupe.
