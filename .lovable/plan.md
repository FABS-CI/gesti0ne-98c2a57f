# Plan de correction : Erreur d'approbation (Enum app_role)

L'erreur "invalid input value for enum app_role: 'admin'" lors de l'approbation d'un retour (RET-20260811-9f4f28) est due à un conflit entre l'ancienne validation de rôle (enum `app_role`) et le nouveau moteur RBAC (`rbac2_user_roles`) au sein de la fonction SQL `approbation_decider`.

## Étapes de correction

1. **Migration SQL** :
   - Modifier `public.approbation_decider` pour utiliser `public.has_role_compat` au lieu de `public.has_role`.
   - `has_role_compat` accepte `text` au lieu de l'enum `app_role`, ce qui résout le conflit de type et utilise la table `rbac2_user_roles`.

2. **Vérification Frontend** :
   - S'assurer que le payload envoyé par `src/routes/_authenticated/approbations.tsx` est correct (déjà vérifié via logs : UUID, 'approuve', null).

3. **Nettoyage Debug** :
   - Retirer les logs `=== APPROVAL DEBUG ===` une fois la correction validée.

## Détails Techniques

- **Source du bug** : Appel à `public.has_role(v_uid, 'admin')` dans `approbation_decider`.
- **Solution** : Remplacer par `public.has_role_compat(v_uid, 'admin')`.
