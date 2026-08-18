### RAPPORT D'AUDIT FORENSIQUE : MODULE COLISAGE (v2.4.0)

## 1. Dernier commit fonctionnel identifié
*   **HASH** : `6bf3801` (stable reference).
*   **DATE** : Historique (Juillet 2026).
*   **DESCRIPTION** : Version complète incluant la distribution manuelle des quantités, la génération de cartons, et l'étiquetage QR.

## 2. Preuve du fonctionnement historique
*   **Composants** : `ColisageForm.tsx` (distribution manuelle), `EtiquetteCarton.tsx` (rendu HTML des stickers), `EtiquettesSection.tsx` (regroupement pour impression).
*   **Logique QR** : Encodage de l'URL `/carton/$id` via la bibliothèque `qrcode`.
*   **Stockage** : Tables `colis` et `colis_lignes` via la RPC `creer_colisage_manuel`.

## 3. Première régression détectée
*   **COMMIT** : `be7cc27` (et suivants).
*   **FICHIER** : `src/components/colisage/EtiquetteCarton.tsx`, `src/lib/colisage-api.ts`.
*   **MODIFICATION** : Introduction erronée du champ `format_carton` (NC4, NC2, etc.) qui n'existait pas dans la version opérationnelle cible.

## 4. Fonctionnement perdu ou altéré
*   **Visuel** : Affichage d'un bloc "FORMAT" sur les étiquettes.
*   **Formulaire** : Sélecteur de format ajouté inutilement.
*   **Architecture** : Pollution des types et des payloads API avec `format_carton`.

## 5. Différences actuelles identifiées
*   Le code actuel contient encore des traces de `format_carton` (commentaires ou types optionnels).
*   La logique de distribution des quantités a été complexifiée par des tentatives de regroupement post-traitement.

## 6. Format carton : Conclusion
*   **Historique** : **NON**. Le champ n'existait pas dans `6bf3801`.
*   **Action** : **SUPPRESSION TOTALE** de l'UI, des types et de la logique métier.

## 7. QR Code & Étiquettes
*   **Logique** : Restauration du rendu centré sans bloc format.
*   **QR** : URL stable `/carton/$id` vers la route publique.

## 8. Impression & PDF
*   **Mécanisme** : Restauration des styles CSS `@media print` pour le format A4 Portrait (2 étiquettes par page).
*   **Stabilité** : Maintien du délai de 800ms pour le rendu QR.

---
*Ce rapport a été établi avant toute modification. La restauration va maintenant procéder à l'alignement strict sur la version fonctionnelle identifiée.*
