# Plan d'audit et correction : Suppression des Tournées Logistiques

Le module de suppression des tournées affiche une erreur de permission malgré l'attribution apparente des droits. L'audit a révélé un décalage entre le moteur de sécurité **RBAC v3** (utilisé par le frontend) et la fonction SQL `supprimer_tournee` (utilisée par le backend) qui repose sur l'ancien système de rôles (**v2**).

## Analyse technique

1.  **Frontend** : Utilise `<Can permission="tournees.supprimer">`. Ce code v2 est correctement traduit depuis la permission v3 `logistique.supprimer` par le pont `rbac3-bridge.ts`.
2.  **Backend** : La RPC `supprimer_tournee` utilise `public.has_role(auth.uid(), 'super_admin')`. Cette fonction vérifie la table `user_roles` (v2) et le type `app_role` (enum v2).
3.  **Cause du bug** : Un utilisateur ayant le rôle `admin` ou `service_logistique` peut voir le bouton (si `logistique.supprimer` est accordé en v3), mais l'exécution échoue car la RPC est verrouillée sur `super_admin` en v2, ou ne reconnaît pas les nouveaux rôles v3.
4.  **Dette technique** : La RPC `supprimer_tournee` a été écrasée par une version simplifiée dans la migration `20260716084920` qui ne gère plus les droits fins ni les cascades complexes restaurées dans d'autres commits.

## Étapes de correction

### 1. Alignement de la sécurité Backend (Migration SQL)
- Mettre à jour `supprimer_tournee` pour utiliser `public.rbac3_can('logistique.supprimer')` au lieu de `has_role`.
- Restaurer la logique de nettoyage complète (colis, livraisons, expéditions, notifications, audits) pour éviter les orphelins.
- Garantir que `super_admin` conserve son bypass total via le moteur `rbac3_can`.

### 2. Vérification Frontend
- Confirmer que la permission demandée est bien `tournees.supprimer`.
- S'assurer que le pont `rbac3-bridge.ts` inclut bien le mapping `supprimer` -> `supprimer`.

### 3. Validation
- Test de suppression avec un compte `admin` (ayant `logistique.supprimer`).
- Vérification de l'intégrité des données après suppression (absence de lignes orphelines dans `colis` et `livraisons`).

## Détails de l'audit
- **Cause du refus** : Utilisation de `has_role('super_admin')` v2 dans le backend alors que l'utilisateur est `admin` v3.
- **Permission attendue** : `tournees.supprimer` (UI) / `logistique.supprimer` (V3).
- **Permission réellement vérifiée** : Rôle `super_admin` (V2) uniquement.
- **Rôle concerné** : Tous les rôles hors Super Admin historique.
- **Fichier concerné** : `supabase/migrations/...` (RPC `supprimer_tournee`).
