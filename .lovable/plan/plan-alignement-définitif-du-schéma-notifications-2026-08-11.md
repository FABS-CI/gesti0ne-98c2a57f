# Plan - Alignement définitif du schéma notifications

Le système de notifications souffre d'un décalage entre le code (SQL et TypeScript) et le schéma réel de la base de données. L'approbation d'un retour échoue car elle tente d'utiliser des colonnes inexistantes (`type`, `metadata`).

## Diagnostic
- **Colonnes réelles en DB** : `notification_id`, `titre`, `message`, `type_notification`, `priorite`, `module`, `lien`, `document_type`, `document_id`, `document_reference`, `user_id`, `role_cible`, `lu`, `date_notification`, `created_at`, `updated_at`.
- **Champs manquants identifiés** :
  - `type` : utilisé par erreur au lieu de `type_notification`.
  - `metadata` : utilisé dans les fonctions SQL mais absent de la table.
- **Fonctions SQL impactées** : `approbation_decider`, `approbation_deleguer`, `notifier_approbateurs_workflow`, `recalculer_sla_approbations`.

## Actions
1. **Migration SQL unique** :
   - Ajouter la colonne `metadata` (JSONB) à la table `notifications`.
   - Harmoniser les fonctions SQL pour utiliser `type_notification` au lieu de `type`.
2. **Alignement TypeScript** :
   - Mettre à jour `src/lib/notifications-api.ts` pour inclure `metadata` dans le type `Notification`.
3. **Vérification** :
   - Tester l'approbation du retour `RET-20260811-9f4f28`.

## Détails Techniques
### Migration
```sql
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS metadata JSONB;
```
Les fonctions SQL seront mises à jour pour pointer vers les bonnes colonnes.
