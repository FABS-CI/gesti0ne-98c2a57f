# Plan — Correction du Module Colisage

L'audit a révélé que la régression dans le module Colisage était causée par des filtres trop restrictifs dans le composant `ColisageCartonsSection`. Le système masquait les articles dès qu'ils étaient considérés comme "répartis", mais la logique de filtrage empêchait parfois d'afficher les articles même quand du stock restait à traiter ou quand l'utilisateur voulait modifier une ligne existante.

## Actions prévues

### Audit technique et fonctionnel
- [x] Vérifier la requête de récupération des articles (OK : `getBLDetail` récupère bien 1500 unités pour le BL test).
- [x] Analyser le calcul des quantités (OK : `attendu` et `reparti` utilisent des Maps basées sur `keyForLigne`).
- [x] Identifier la cause du message "Tous les articles ont été répartis" (OK : filtre restrictif `optionsDisponibles` dans le `Select`).

### Corrections de la logique existante
- [x] Simplifier le filtrage des options dans le sélecteur d'articles pour toujours afficher tous les articles de la commande.
- [x] Marquer comme "Réparti" (disabled) uniquement les articles dont la quantité restante est réellement à zéro (en tenant compte de la ligne en cours d'édition).
- [x] Trier la liste pour mettre en avant les articles disposant encore de quantités à répartir.
- [x] Nettoyer l'affichage du tableau récapitulatif "Produits à coliser" pour éviter les confusions de quantités lors de la préparation.

### Validation
- [x] Tester avec un BL réel (BL-2026-00014).
- [x] Vérifier que le sélecteur propose bien les articles même si des répartitions partielles existent.
- [x] Confirmer que le calcul du "Reste" est cohérent (Commande - Déjà réparti).

## Détails techniques
- Modification de `src/components/colisage/form/ColisageCartonsSection.tsx` pour supprimer le filtrage amont des options.
- Mise à jour de `src/routes/_authenticated/colisage.$blId.tsx` pour stabiliser l'affichage du récapitulatif.
