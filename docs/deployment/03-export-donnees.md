# 📤 Export du code et des données

## 1. Export du code (frontend)

### Via GitHub (recommandé)
1. Dans Lovable : menu **+** (bas à gauche du chat) → **GitHub**
2. Cliquer **Create Repository**
3. Autoriser Lovable à créer un repo sur votre compte GitHub
4. Cloner en local :
   ```bash
   git clone https://github.com/<votre-user>/<repo>.git
   cd <repo>
   bun install
   bun run build
   ```
5. Vérifier que le build passe sans erreur

### Fichiers importants à conserver
```
supabase/migrations/         # ⚠️ CRITIQUE — toutes les migrations SQL
supabase/config.toml         # config projet (project_id à changer)
src/                         # tout le code frontend + server functions
package.json + bun.lock      # dépendances
vite.config.ts, tsconfig.json
docs/deployment/             # ce dossier
.env.example                 # modèle des variables
```

### Fichiers à NE PAS copier tels quels
- `src/integrations/supabase/client.ts` — sera régénéré avec les nouvelles clés
- `src/integrations/supabase/types.ts` — sera régénéré depuis le nouveau Supabase
- `.env` — doit être recréé avec les nouvelles valeurs

## 2. Export des données (base de données)

### Méthode A — Via Lovable Cloud (le plus simple)
1. Dans Lovable : ouvrir **Cloud** (bouton en haut)
2. **Advanced settings** → **Export data**
3. Lovable prépare l'export (peut prendre plusieurs minutes selon volume)
4. Vous recevrez un fichier ZIP contenant les tables en CSV

⚠️ Cet export **n'inclut pas** :
- Les utilisateurs de `auth.users` (Supabase gère cette table)
- Le contenu de Storage (fichiers uploadés)

### Méthode B — Export SQL via `pg_dump` (si accès autorisé)
Non disponible sur Lovable Cloud pour l'instant. À demander au support Lovable si nécessaire.

### Export des utilisateurs Auth
Depuis le futur Supabase, utiliser l'API Auth Admin :
```bash
# À faire depuis un script Node avec la service_role_key
supabase.auth.admin.listUsers()
```
Les utilisateurs devront être **recréés** dans le nouveau projet, et un email de reset password envoyé (les mots de passe ne sont jamais transférables).

**Alternative** : demander à tous les utilisateurs de se réinscrire (plus simple mais impactant).

### Export du Storage
Pour chaque bucket :
```bash
# Lister les buckets côté Supabase Cloud actuel — non exposé par Lovable
# Solution : recréer les buckets et re-uploader depuis vos sauvegardes locales
```
Si vos utilisateurs ont uploadé des documents/images, il faudra soit :
- Contacter le support Lovable pour un export Storage
- Recréer les buckets vides et demander re-upload

## 3. Liste des secrets/env à récupérer

Voir `06-variables-environnement.md`. Vous devez lister avant migration :
- Toutes les clés API tierces (FNE, SMS, email...)
- Google OAuth Client ID + Secret (à recréer depuis Google Cloud Console)
- Toute clé stockée via `add_secret` dans Lovable

Dans Lovable, aller dans **Project Settings → Secrets** pour voir les noms des secrets (les valeurs ne sont pas exposées, à récupérer depuis les services d'origine).
