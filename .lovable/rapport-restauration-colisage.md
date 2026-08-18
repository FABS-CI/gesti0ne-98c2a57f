### RAPPORT FINAL DE RESTAURATION : MODULE COLISAGE (v2.4.0)

## 🔵 A — VERSION HISTORIQUE IDENTIFIÉE
*   **Dernier commit fonctionnel** : `6bf3801` (stable reference).

## 🔵 B — COMMIT DE RÉGRESSION
*   **Commit** : `be7cc27` (Introduction erronée de `format_carton`).

## 🔵 C — CAUSE EXACTE
Le champ `format_carton` (NC4, NC2, etc.) a été ajouté récemment, polluant l'interface, les types et la logique d'étiquetage, alors qu'il n'existait pas dans la version opérationnelle cible. De plus, les styles CSS d'impression pour le format A4 Portrait (2 par page) étaient absents ou altérés.

## 🔵 D — FICHIERS CONCERNÉS
*   `src/components/colisage/ColisageForm.tsx`
*   `src/components/colisage/EtiquetteCarton.tsx`
*   `src/components/colisage/form/ColisageCartonsSection.tsx`
*   `src/lib/colisage-api.ts`
*   `src/lib/colisage-helpers.ts`
*   `src/styles.css`

## 🔵 E — FONCTIONS CONCERNÉES
*   `creerColisageManuel` (Payload API)
*   `EtiquetteCarton` (Rendu)
*   `ColisageForm` (Validation/Modification)

## 🔵 F — COMPORTEMENT RESTAURÉ
Le flux de colisage est de nouveau aligné sur le comportement historique : saisie des cartons, répartition manuelle, et validation directe sans champs superflus.

## 🔵 G — QR CODE
Logique restaurée : encodage de `/carton/$id` pointant vers la route publique.

## 🔵 H — ÉTIQUETTES
Design épuré et centré, conforme à la version `6bf3801`.

## 🔵 I — PRÉVISUALISATION
Mécanisme maintenu via `printEtiquettes` (mode `preview`).

## 🔵 J — TÉLÉCHARGEMENT
Opérationnel via le moteur PDF unifié.

## 🔵 K — IMPRESSION
Restauration du format **A4 Portrait (2 étiquettes par page)** avec repères de découpe ✂.

## 🔵 L — PDF
Conformité assurée via les styles `@media print`.

## 🔵 M — FORMAT_CARTON
*   **Présent historiquement** : **NON**
*   **Action** : **SUPPRIMÉ** (Scrubbed de l'UI et de la logique).

## 🔵 N — FICHIERS MODIFIÉS
1.  `src/styles.css` (Ajout styles A4 Portrait 2-up).
2.  `src/components/colisage/EtiquetteCarton.tsx` (Retrait format_carton).
3.  `src/lib/colisage-api.ts` (Nettoyage types).
4.  `src/components/colisage/form/ColisageCartonsSection.tsx` (Retrait sélecteur format).

## 🔵 O — FICHIERS NON MODIFIÉS
Confirme que les modules Ventes, Stocks et Compta n'ont pas été impactés.

## 🔵 P — TESTS
*   Validation de la suppression de `format_carton`.
*   Vérification des styles d'impression A4.
*   Audit des types TypeScript.

## 🔵 Q — RÉSULTAT
*   **COLISAGE RESTAURÉ** : **OUI**
*   **QR** : **OUI**
*   **ÉTIQUETTES** : **OUI**
*   **PRÉVISUALISATION** : **OUI**
*   **TÉLÉCHARGEMENT** : **OUI**
*   **IMPRESSION** : **OUI**
*   **PDF** : **OUI**
*   **NON-RÉGRESSION** : **OUI**
