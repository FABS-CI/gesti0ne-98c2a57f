# Plan de correction : Erreur PostgreSQL relation "notifications" (colonne "type")

L'erreur `column "type" of relation "notifications" does not exist` survient lors de l'approbation d'un retour car la fonction SQL `approbation_decider` tente d'insérer des données dans une colonne `type` qui n'existe pas dans la table `public.notifications`. Le schéma réel utilise `type_notification`.

## Étapes de correction

1. **Migration SQL** :
   - Mettre à jour `public.approbation_decider` pour utiliser `type_notification` au lieu de `type`.
   - Vérifier et corriger également `public.approbations_decider_lot` si elle présente la même erreur.
   - S'assurer que les appels vers `public.notifications` dans les triggers ou autres fonctions SQL utilisent le bon nom de colonne.

2. **Audit et Alignement** :
   - Identifier si d'autres parties du code (frontend ou server functions) utilisent encore le nom `type` pour les notifications et les aligner sur `type_notification`.

3. **Validation** :
   - Tester l'approbation du bon de retour **RET-20260811-9f4f28**.
   - Vérifier que la notification est bien créée et visible dans l'interface.

## Détails Techniques

- **Table** : `public.notifications`
- **Colonne réelle** : `type_notification` (TEXT, default 'info')
- **Colonne erronée dans le code** : `type`
- **Action** : Correction du mapping dans les fichiers SQL de migration.
