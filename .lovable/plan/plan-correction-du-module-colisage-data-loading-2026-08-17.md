# Plan - Correction du module Colisage (Data Loading)

Audit et correction de la récupération des articles dans le module Colisage pour résoudre l'affichage « Aucune ligne » alors que la commande contient des produits.

## Problème identifié
Le système affiche correctement le nombre d'articles dans le récapitulatif (ex: 3 articles, 900 unités), mais la section « Produits à coliser » et le formulaire de création de cartons restent vides. Cela indique une rupture dans la récupération des lignes de commande ou un filtrage excessif.

## Étapes de résolution

### 1. Audit des données (Backend/API)
- [ ] Vérifier si `commande_id` est bien présent sur le BL.
- [ ] Confirmer que `commande_lignes` contient des données pour cet ID.
- [ ] Vérifier les permissions RLS sur `commande_lignes`.

### 2. Correction de `src/lib/colisage-api.ts`
- [ ] Supprimer les logs de debug après confirmation.
- [ ] S'assurer que la jointure avec `produits` (pour `cover_path`) ne bloque pas le retour des lignes si le produit est manquant ou si la jointure échoue.
- [ ] Garantir que `lignes` est retourné même si `facture_reference` est nul.

### 3. Fiabilisation du Frontend
- [ ] Vérifier dans `src/routes/_authenticated/colisage.$blId.tsx` que le rendu de la table utilise bien les données brutes de `bl.lignes` sans filtrage préalable.
- [ ] S'assurer que `useColisageDetail` ne masque pas d'erreurs silencieuses.

### 4. Tests de validation
- [ ] Tester avec la commande `CMD-2026-00001`.
- [ ] Vérifier l'affichage des 3 articles.
- [ ] Vérifier que les articles sont sélectionnables dans le formulaire de carton.

## Détails techniques
- La fonction `getBLDetail` est le point d'entrée unique pour ces données.
- Le mapping des lignes doit être robuste aux valeurs nulles dans les jointures.
