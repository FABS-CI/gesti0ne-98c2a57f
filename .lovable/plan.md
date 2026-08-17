# Restauration de la modification du colisage existant

Le module Colisage doit charger l'intégralité des données enregistrées lorsqu'un colisage existant est ouvert pour modification. La logique actuelle pré-remplit certains champs mais semble perdre la structure complète ou la relation avec les articles de la commande dans certains cas.

## Modifications prévues

### 1. Backend & RLS
- Vérifier que la fonction `creer_colisage_manuel` gère correctement la suppression et recréation (déjà le cas via `DELETE FROM public.colis WHERE bl_id = _bl_id`).
- Mettre à jour `global_search` pour inclure les cartons (déjà fait, mais vérification de la redirection).

### 2. Frontend (Composants)
- **`ColisageForm.tsx`** :
    - Améliorer le `useEffect` d'initialisation pour garantir que l'état `cartons` est fidèlement restauré à partir de `colisExistants`.
    - S'assurer que les quantités "reparties" sont correctement calculées par rapport aux lignes de la commande pour afficher les écarts réels.
    - Ajouter un bouton explicite "Modifier le colisage" pour les colisages terminés (si l'utilisateur a les permissions), car actuellement il est affiché sous "Refaire le colisage".
- **`ColisageCartonsSection.tsx`** :
    - Vérifier que les lignes de chaque carton sont correctement affichées avec leur désignation historique.

### 3. UX & Workflow
- Assurer que le clic sur "Modifier" charge bien les données sans créer de doublons.
- Garantir que les étiquettes existantes restent consultables pendant la modification.

## Test de validation
1. Ouvrir un colisage existant (ex: `COL-XXXXX`).
2. Vérifier que tous les cartons et leur contenu (articles, quantités) sont affichés.
3. Modifier une quantité dans un carton.
4. Enregistrer et vérifier que les anciens colis ont été remplacés par les nouveaux sans perte de cohérence.
