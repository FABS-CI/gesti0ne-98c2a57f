# Plan de correction — Module Retours (ERP FABS-CI)

Correction du format des numéros de retour et du workflow de changement de statut.

## 1. Normalisation du numéro de retour (RET-YYMMDD-XXX)
- Modification de la fonction SQL `retour_creer_demande` pour implémenter la nouvelle séquence.
- Utilisation d'un format `RET-260811-001` (YYMMDD-XXX) garantissant l'unicité journalière sans UUID visible.
- Conservation de la compatibilité avec les anciens numéros.

## 2. Correction du workflow et du changement de statut
- Audit de la chaîne complète : Frontend -> RPC -> PostgreSQL -> Rechargement.
- Identification de la cause racine : Désalignement entre les libellés frontend et les valeurs backend, et gestion incomplète des rechargements de cache (TanStack Query).
- Harmonisation des statuts entre `STATUTS_RETOUR` (frontend) et les transitions forcées dans les RPC (`approbation_decider`, `retour_receptionner`, `retour_valider_compta`).
- Forçage du rechargement des données après chaque action critique pour garantir l'affichage immédiat du nouveau statut.

## Détails techniques

### Modifications SQL (Migration)
- **`retour_creer_demande`** : Nouveau format de `numero` avec séquence journalière.
- **`approbation_decider`** : Alignement du statut de retour sur `attente_reception` (ou autre selon le workflow attendu) au lieu de `approuve` si c'est une étape intermédiaire.
- **Audit de la table `retours`** : Confirmation de l'usage de la colonne `statut`.

### Modifications Frontend
- **`src/lib/retours-api.ts`** : Mise à jour de `STATUTS_RETOUR` pour correspondre exactement aux valeurs backend.
- **`src/routes/_authenticated/retours.$retourId.tsx`** : Amélioration de la gestion des mutations pour invalider systématiquement les caches et forcer un "refetch".
- **`src/routes/_authenticated/approbations.tsx`** : Invalidation du cache des retours lors de l'approbation d'un module "retour".

## Workflow cible
1. **Création** : `demande_creee` (ou `attente_reception` si auto-validé).
2. **Validation Demande** (si applicable) : `attente_reception`.
3. **Réception Magasin** : `attente_validation_compta`.
4. **Validation Compta** : `cloture` (ou `valide_compta`).
