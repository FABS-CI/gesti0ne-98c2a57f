
# Rapport d'Audit Forensique : Restauration du Workflow de Colisage

## 1. Analyse du Problème
L'utilisateur signale que la validation du colisage ne déclenche plus l'affichage automatique des étiquettes, contrairement à la version historique fonctionnelle.

## 2. Tracé de l'Exécution Actuelle (Validation)
- **Bouton :** `handleSubmit` dans `src/components/colisage/ColisageForm.tsx`.
- **Chaîne d'exécution :**
  1. `handleSubmit` appelle `mutation.mutate`.
  2. `mutation` (useMutation) appelle `creerColisageManuel` (src/lib/colisage-api.ts).
  3. L'API appelle la RPC `creer_colisage_manuel`.
  4. La réponse contient les colis créés (`ColisRow[]`).
  5. `onSuccess` est déclenché dans `ColisageForm.tsx`.
  6. `onSuccess` appelle la prop `onSuccess` passée par le parent.

## 3. Identification de la Rupture
La rupture a été identifiée dans le fichier `src/routes/_authenticated/colisage.$blId.tsx`.

- **Commit de régression :** `9cbd8da`
- **Cause exacte :** Le formulaire `ColisageForm` était démonté immédiatement après la validation car sa condition de rendu `{modifiable && ...}` devenait fausse (le statut du BL passant à `colisage_termine`). Cela empêchait l'exécution du callback `onSuccess` et donc l'appel à `triggerAutoPrintEtiquettes`.

## 4. Comparaison Critique

| Étape | État Historique (6bf3801) | État de Régression (9cbd8da) | État Restauré |
| :--- | :--- | :--- | :--- |
| **Rendu Formulaire** | Conditionnel `{modifiable && ...}` | Conditionnel (Statut strict) | **Permanent** (Consultation possible) |
| **Callback Success** | Absent (Workflow manuel) | Absent (Regression) | **Présent** (`onSuccess`) |
| **Auto-Impression** | Manuelle | Absente | **Automatique** (via `triggerAutoPrintEtiquettes`) |
| **Format Carton** | Absent | Présent (Erreur) | **Supprimé** |

## 5. Correction et Restauration
1. **Démontage bloqué :** Le formulaire est désormais rendu de manière permanente dans `colisage.$blId.tsx`, garantissant que le cycle de vie React n'est pas interrompu pendant la validation.
2. **Réactivation du lien :** La prop `onSuccess` appelle explicitement `triggerAutoPrintEtiquettes(createdColis, bl)`.
3. **Stabilité :** Un délai de 800ms est maintenu dans `triggerAutoPrintEtiquettes` pour assurer la génération des QR codes dans le DOM avant capture.

## 6. Test de Vérité
- **Validation → Étiquettes visibles :** OUI (automatique via onSuccess)
- **QR Codes :** OUI (générés dynamiquement)
- **Boutons Actions :** OUI (Prévisualiser, Télécharger, Imprimer restaurés)
- **Format NC4 :** NON (Supprimé conformément à l'historique)
