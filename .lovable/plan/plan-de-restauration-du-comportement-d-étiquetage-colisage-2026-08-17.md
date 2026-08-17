# Plan de Restauration du Comportement d'Étiquetage (Colisage)

Je vais restaurer le comportement historique du module Colisage, en permettant la saisie et l'affichage des types de cartons (NC4, NC2, etc.) et en garantissant que les étiquettes sont immédiatement accessibles et imprimables après validation.

## Analyse de la régression
Le système actuel permet de créer des cartons génériques avec un poids et des observations, mais la notion de "Type/Format de carton" (NC4, NC2, etc.) mentionnée par l'utilisateur n'est pas présente dans les composants frontend actuels (`CartonState`). Bien que le scan et la persistance aient été restaurés récemment, l'interface de saisie des formats et leur affichage sur les étiquettes manquent.

## Modifications à apporter

### 1. Backend (SQL)
- Ajouter une colonne `format_carton` (text) à la table `public.colis` via une migration.
- Mettre à jour la fonction RPC `creer_colisage_manuel` pour accepter et enregistrer ce champ.

### 2. Types Frontend
- Mettre à jour `CartonState` dans `src/components/colisage/form/colisage-form-types.ts` pour inclure `format: string`.
- Mettre à jour `CartonManuel` et `ColisRow` dans `src/lib/colisage-api.ts`.

### 3. Interface de Saisie (`ColisageCartonsSection`)
- Ajouter un sélecteur de format de carton dans chaque bloc carton.
- Les formats par défaut seront : NC4, NC2, 2C4, 3C4 (et une option "Autre").

### 4. Modèle d'Étiquette (`EtiquetteCarton`)
- Afficher le format du carton de manière proéminente sur l'étiquette.
- S'assurer que les informations de contenu (produits/quantités) sont parfaitement lisibles pour le contrôle.

### 5. Workflow de Restauration (`ColisageForm` & `ColisageDetailPage`)
- Garantir que lors du chargement d'un colisage existant, le format est bien récupéré.
- S'assurer que la section `EtiquettesSection` est immédiatement mise à jour et visible après validation.

## Détails Techniques

### Migration SQL
```sql
ALTER TABLE public.colis ADD COLUMN IF NOT EXISTS format_carton text;

-- La fonction creer_colisage_manuel doit être mise à jour pour mapper 
-- le champ format de l'entrée JSON vers la colonne format_carton.
```

### Formats de cartons prévus
- **NC4** : Nouveau Carton 4
- **NC2** : Nouveau Carton 2
- **2C4** : 2 Cartons type 4 (ou équivalent historique)
- **3C4** : 3 Cartons type 4
- **VRAC** : Articles non emballés
- **AUTRE** : Format personnalisé

L'objectif est que dès la validation, l'utilisateur voit ses cartons avec leurs formats respectifs et puisse les imprimer en un clic.
