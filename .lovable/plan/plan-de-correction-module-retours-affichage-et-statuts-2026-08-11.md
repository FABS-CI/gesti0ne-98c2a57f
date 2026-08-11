# Plan de correction : Module Retours (Affichage et Statuts)

Ce plan vise à corriger les problèmes de chevauchement dans les tableaux du module Retours et à garantir une cohérence visuelle des statuts entre la liste et le détail.

## Modifications interface utilisateur (UI)

### 1. Correction du chevauchement dans la liste des retours
- Modifier `src/routes/_authenticated/retours.index.tsx` pour forcer des largeurs minimales et une gestion du débordement sur les colonnes critiques.
- Utiliser des pourcentages fixes pour stabiliser le tableau :
    - N° : 8%
    - Date : 10%
    - Client : 25%
    - Représentant : 15%
    - Ville : 10%
    - Qté : 7%
    - Statut : 15% (Badge compact)
    - Actions : 10% (Aligné à droite)

### 2. Correction du chevauchement dans le détail d'un retour
- Modifier `src/routes/_authenticated/retours.$retourId.tsx` pour appliquer une grille de largeurs strictes sur le tableau des produits retournés.
- Structure cible :
    - N° (Index) : 5%
    - Code (Référence) : 12%
    - Désignation : 35% (avec `break-words`)
    - Qté demandée : 10%
    - Qté reçue : 10%
    - État : 13%
    - Motif : 15%

### 3. Uniformisation des badges de statut
- Harmoniser les composants `Badge` pour utiliser les mêmes couleurs et libellés que `src/lib/retours-api.ts`.
- S'assurer que le statut "En attente validation" est affiché de manière cohérente (Orange).

## Modifications techniques (PDF & API)

### 1. Correction du template PDF des retours
- Mettre à jour `src/lib/pdf/retour-document.ts` pour utiliser les mêmes proportions que l'interface afin d'éviter les chevauchements dans le rendu PDF.
- Ajuster `src/lib/pdf/unified-generator.ts` pour s'assurer que les métadonnées de validation (demandeur, approbateur, date) sont correctement transmises au moteur PDF.

### 2. Synchronisation des données
- Vérifier que `buildRetourDocBaseFrom` dans `src/lib/pdf/retour-builder.ts` extrait correctement les informations de validation pour le PDF.

## Détails techniques
- Utilisation de classes Tailwind `min-w-[...]`, `max-w-[...]`, et `break-words`.
- Remplacement de `TableHead` génériques par des versions typées avec largeur explicite.
- Aucun changement de schéma base de données requis (déjà validé).
