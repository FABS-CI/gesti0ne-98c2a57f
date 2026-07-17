# Restauration complète de l'ERP GESTI-ONE sur une nouvelle instance

Cette procédure permet de **reconstituer l'ERP à l'identique** sur un nouvel environnement (nouveau projet Supabase, nouveau domaine) à partir des artefacts de sauvegarde. Suivez les étapes **dans l'ordre** — chaque étape dépend de la précédente.

---

## 0. Prérequis : les 4 artefacts obligatoires

Avant de démarrer, rassemblez ces 4 fichiers dans un dossier local :

| # | Artefact | Source | Contenu |
|---|---|---|---|
| 1 | **Code source** | `git clone` du repo GitHub | Frontend + migrations SQL + edge functions |
| 2 | **`backup_YYYY-MM-DD.json`** | Page `/backup` → « Créer une sauvegarde maintenant » | Dump des ~60 tables métier (données) |
| 3 | **`auth_users_YYYY-MM-DD.json`** + **`storage_manifest_YYYY-MM-DD.json`** | Page `/backup` → « Export critique — Comptes & Fichiers » | Comptes `auth.users` + inventaire Storage |
| 4 | **`storage_binaries_YYYY-MM-DD.zip`** | Page `/backup` → « ZIP binaires Storage » | Fichiers réels des buckets (covers, avatars, RH) |

⚠️ **L'artefact 4 est indispensable si la restauration a lieu plus de 7 jours après l'export** (les URLs signées du manifest expirent après 7 jours).

---

## 1. Créer le nouveau projet Supabase / Lovable Cloud

1. Créer un nouveau projet Lovable (ou Supabase self-hosted).
2. Noter la nouvelle `SUPABASE_URL` et la `SUPABASE_PUBLISHABLE_KEY` (anon key).
3. Récupérer la `SERVICE_ROLE_KEY` (uniquement côté self-hosted — sur Lovable Cloud elle n'est pas accessible mais elle est injectée automatiquement dans les server functions).

---

## 2. Restaurer le schéma (structure)

1. Cloner le repo : `git clone <url-github> && cd <projet>`
2. Lier le nouveau projet Supabase : `supabase link --project-ref <nouveau-ref>`
3. Appliquer **toutes** les migrations dans l'ordre chronologique :
   ```bash
   supabase db push
   ```
4. Vérifier la présence des ~100 tables, des ~85 RPC `SECURITY DEFINER`, et des politiques RLS.

---

## 3. Restaurer les comptes utilisateurs (`auth.users`)

À partir de `auth_users_YYYY-MM-DD.json` :

1. Ouvrir le fichier — il contient 16+ comptes avec leurs `id`, `email`, `user_metadata`, `app_metadata`, `identities`.
2. **Re-créer chaque compte** via l'API admin Supabase (script Node.js) :
   ```ts
   import { createClient } from "@supabase/supabase-js";
   const admin = createClient(URL, SERVICE_ROLE_KEY);
   for (const u of users) {
     await admin.auth.admin.createUser({
       email: u.email,
       email_confirm: true,
       user_metadata: u.user_metadata,
       app_metadata: u.app_metadata,
       id: u.id, // ⚠️ conserver l'UUID original pour préserver les FK
     });
   }
   ```
3. **Envoyer un mail de reset password** à chaque utilisateur (les mots de passe ne sont **pas** exportables pour raisons de sécurité) :
   ```ts
   await admin.auth.admin.generateLink({ type: "recovery", email: u.email });
   ```
4. Reconfigurer les providers OAuth (Google, etc.) dans les paramètres Auth du nouveau projet.

---

## 4. Restaurer les données métier (~60 tables)

À partir de `backup_YYYY-MM-DD.json` :

1. Ouvrir la page `/backup` du nouvel ERP (connecté en super_admin).
2. Utiliser le composant **« Restauration depuis JSON »** (`BackupRestoreCard`).
3. Ordre recommandé (respect des FK) :
   - Référentiels : `depots`, `categories_produits`, `plan_comptable`, `journaux_comptables`, `rbac_*`
   - Tiers & catalogue : `clients`, `fournisseurs`, `produits`, `employes`
   - Stock : `stocks_depots`, `stock_mouvements`
   - Commercial : `commandes` → `commande_lignes` → `bons_livraison` → `factures` → `paiements`
   - Reste : audit, notifications, etc.

⚠️ **Ne pas restaurer les tables `mfa_*`, `login_history`, `perf_query_log`** — elles se re-remplissent d'elles-mêmes.

---

## 5. Restaurer les fichiers Storage

1. Recréer les buckets dans le nouveau projet : `product-covers`, `avatars`, `employe-photos`, `employe-documents` (mêmes noms, mêmes politiques d'accès — copier depuis `supabase/config.toml`).
2. **Décompresser** `storage_binaries_YYYY-MM-DD.zip` localement — la structure interne est :
   ```
   product-covers/<uuid>.jpg
   avatars/<uuid>.png
   employe-photos/<uuid>.jpg
   employe-documents/<path>
   manifest.json
   ```
3. **Uploader** chaque dossier dans son bucket homonyme via l'API Storage :
   ```ts
   const { data } = await admin.storage
     .from("product-covers")
     .upload(relPath, fileBuffer, { upsert: true, contentType });
   ```
4. Vérifier que les colonnes DB (`produits.cover_path`, `employes.photo_url`, etc.) pointent bien vers les fichiers uploadés — les chemins doivent être identiques à ceux du ZIP.

---

## 6. Configurer les connecteurs & secrets

1. **Connecteur Google Drive** : reconnecter via `/admin/google-drive` (compte Google, portées `drive.file` + `drive.readonly`).
2. **Secrets d'environnement** à recréer manuellement (non exportables) :
   - `LOVABLE_API_KEY` (auto-provisionné)
   - `GOOGLE_DRIVE_API_KEY` (via reconnexion connecteur)
   - Tout secret métier propre à l'entreprise (FNE, SMS, etc.)
3. Reconfigurer les workflows GitHub Actions (`.github/workflows/*.yml`) avec les nouvelles clés.

---

## 7. Déployer & valider

1. `bun install && bun run build` — la build doit passer sans erreur.
2. Publier le projet (bouton **Publish** dans Lovable).
3. Configurer le domaine personnalisé si applicable.
4. Se connecter avec un compte super_admin (mail de reset reçu à l'étape 3).
5. **Checklist de validation** :
   - [ ] La page `/dashboard` affiche les KPIs
   - [ ] La liste `/produits` montre les couvertures
   - [ ] Une commande passe le cycle Commande → BL → Facture → Paiement
   - [ ] Les rôles RBAC sont bien appliqués (tester avec un compte non-admin)
   - [ ] L'export PDF fonctionne
   - [ ] `/backup` peut relancer une sauvegarde (test end-to-end)

---

## 8. Post-restauration

- **Rotation `LOVABLE_API_KEY`** : via `lovable_api_key--rotate` pour repartir sur une clé fraîche.
- **Purge des artefacts anciens** dans le dossier Google Drive « DONNEE GESTI-ONE » (garder les 3 derniers exports).
- **Cron `pg_cron`** : reconfigurer les jobs planifiés (`run-schedules`) avec la nouvelle URL de projet.
- **Documenter la date de restauration** dans un fichier `RESTORATION-LOG.md` à la racine.

---

## Fiabilité et couverture

| Élément | Couverture après restauration |
|---|---|
| Schéma DB (tables, RPC, RLS, triggers) | 100 % (via migrations) |
| Données métier (~60 tables) | 100 % (via JSON) |
| Comptes utilisateurs (id, email, métadonnées) | 100 % (via auth_users.json) |
| Mots de passe utilisateurs | **0 %** — reset obligatoire (protection Supabase) |
| Sessions actives, MFA TOTP secrets | **0 %** — à réinitialiser |
| Fichiers Storage (covers, avatars, RH) | 100 % (via ZIP binaires) |
| Logs audit historiques | Selon inclusion dans le JSON |
| Historique d'exécution `pg_cron` | 0 % — repart à zéro |

**Fiabilité globale : ~98 %.** Les 2 % restants (mots de passe, MFA, sessions) sont volontairement non exportables pour raisons de sécurité et se reconstituent en < 24 h après notification aux utilisateurs.

---

## Support

En cas de blocage à une étape, consulter `docs/runbook-incidents.md` ou contacter le support Lovable.
