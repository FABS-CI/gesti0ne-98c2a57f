# Suppression Totale et Définitive du MFA

Ce plan détaille les étapes pour retirer complètement le système d'authentification multifacteur (MFA/TOTP) de l'application, en suivant les consignes de l'audit préalable.

## Actions à réaliser

### 1. Base de données
- Créer une migration SQL pour supprimer les tables liées au MFA : `two_fa_secrets`, `mfa_backup_codes`, `mfa_otp_attempts`, `mfa_session_validations`.
- Supprimer les colonnes liées au MFA dans la table `profiles` : `mfa_required`, `mfa_enrolled_at`.
- Supprimer les fonctions et triggers associés (ex: `check_mfa_session`).

### 2. Backend (Server Functions)
- Supprimer `src/lib/mfa.functions.ts` qui contient les fonctions de configuration et de vérification.
- Nettoyer `src/lib/users.functions.ts` de toute référence au statut MFA.

### 3. Frontend - Routes et Layouts
- Supprimer les routes `src/routes/_authenticated/mfa.enroll.tsx` et `src/routes/_authenticated/mfa.backup-codes.tsx`.
- Modifier `src/routes/_authenticated/route.tsx` pour retirer le composant `<MfaGate>`.
- Supprimer le composant `src/components/mfa/MfaGate.tsx`.
- Supprimer le dossier `src/components/mfa/`.

### 4. Frontend - UI de gestion
- Modifier `src/components/security/UsersAdmin.tsx` pour retirer les colonnes et boutons de gestion du MFA (Activer/Désactiver).
- Modifier `src/routes/_authenticated/profil.tsx` pour retirer les options MFA du profil utilisateur.

### 5. Nettoyage du Code et Dépendances
- Retirer les imports inutilisés de `otpauth` et `input-otp` (sauf si `input-otp` est utilisé ailleurs, à vérifier).
- Nettoyer les définitions RBAC dans `src/lib/rbac-catalog.ts`, `src/lib/rbac-permission-codes.ts` et `src/lib/route-permissions.ts`.
- Supprimer le fichier de mémoire projet `mem://features/mfa-control.md`.

### 6. Vérification
- Vérifier que la connexion (Email/MDP) fonctionne pour tous les rôles.
- Vérifier que le menu latéral et le contenu principal s'affichent correctement.
- S'assurer qu'aucune référence résiduelle n'empêche le build.

## Détails techniques

### Dépendances à supprimer (via bun remove)
- `otpauth`

### Tables à supprimer (SQL)
- `public.two_fa_secrets`
- `public.mfa_backup_codes`
- `public.mfa_otp_attempts`
- `public.mfa_session_validations`

### Modifications de schéma (SQL)
- `ALTER TABLE public.profiles DROP COLUMN IF EXISTS mfa_required;`
- `ALTER TABLE public.profiles DROP COLUMN IF EXISTS mfa_enrolled_at;`
