# Règle de sécurité — migrations SQL

## Interdiction absolue : pas de secret en clair dans une migration

Aucun mot de passe, jeton, clé API ou secret TOTP ne doit apparaître en clair
dans un fichier de `supabase/migrations/`, **même temporairement**. Une migration
est commitée dans le dépôt : le secret reste lisible dans l'historique Git à vie,
même s'il est chiffré au moment de l'exécution (`crypt(...)`).

Incident de référence : `20260629202940_c9007c21-da35-4296-84d3-f4cf08146313.sql`
créait 9 comptes réels avec des mots de passe littéraux. Ces mots de passe sont
considérés comme **compromis définitivement** et doivent être rotés en base.

## Ce qu'il faut faire à la place

Pour créer/seeder des comptes :

1. Générer le mot de passe **aléatoirement au moment de l'exécution**, jamais dans le fichier :
   ```sql
   crypt(encode(gen_random_bytes(24), 'base64'), gen_salt('bf'))
   ```
   La valeur n'est jamais affichée ni stockée en clair.
2. Marquer le compte comme devant changer de mot de passe :
   `profiles.must_change_password = true`.
3. Envoyer une invitation / un lien de réinitialisation par e-mail à l'utilisateur.
   C'est lui, et lui seul, qui choisit son mot de passe.

## Corriger une fuite passée

Ne **jamais** réécrire une migration déjà appliquée (règle Lovable, cf. `AGENTS.md`).
Ajouter une **nouvelle** migration qui :

- invalide le mot de passe compromis (rotation vers une valeur aléatoire),
- positionne `must_change_password = true`,
- révoque les sessions/refresh tokens existants des comptes concernés.

## Revue

Toute migration ajoutant/modifiant `auth.users` doit être relue avec ce document.
Recherche de contrôle avant merge :

```bash
rg -n "crypt\(|password|mot de passe" supabase/migrations/
```
