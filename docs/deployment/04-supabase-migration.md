# 🗄️ Recréer le backend Supabase

Deux options : **Supabase Cloud** (managé, recommandé) ou **Self-hosted** (Docker sur VPS).

## Option A — Supabase Cloud (recommandé)

### 1. Créer le projet
1. Aller sur https://supabase.com/ → **New project**
2. Choisir la région la plus proche de vos utilisateurs (Europe recommandé si utilisateurs FR/CI)
3. Choisir un mot de passe DB fort (à conserver précieusement)
4. Attendre 2-3 min la création

### 2. Récupérer les clés
Dans **Project Settings → API** :
- `Project URL` → sera votre `SUPABASE_URL` et `VITE_SUPABASE_URL`
- `anon public` (ou `sb_publishable_...`) → `SUPABASE_PUBLISHABLE_KEY` et `VITE_SUPABASE_PUBLISHABLE_KEY`
- `service_role secret` (ou `sb_secret_...`) → `SUPABASE_SERVICE_ROLE_KEY` ⚠️ **JAMAIS côté client**

### 3. Rejouer les migrations
Installer la CLI Supabase :
```bash
npm install -g supabase
supabase login
supabase link --project-ref <votre-nouveau-ref>
```

Depuis le dossier du projet cloné :
```bash
supabase db push
```

Cela va **rejouer les 428 migrations** dans l'ordre. Compter 5-15 min.

**Alternative manuelle** : concaténer toutes les migrations et exécuter via `psql` :
```bash
cat supabase/migrations/*.sql | psql "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres"
```

### 4. Vérifier
Dans **Supabase Dashboard → Database → Tables** :
- Vérifier que ~97 tables sont créées dans `public`
- Chaque table doit avoir **RLS enabled** (icône verrou)
- Aller dans **Database → Functions** : ~260 fonctions présentes

Dans **Auth → Providers** :
- Email : activé
- Google : à configurer (voir `07-auth-oauth.md`)

### 5. Importer les données
Depuis les CSV exportés de Lovable Cloud :

**Via SQL Editor** :
```sql
-- Exemple pour clients
COPY public.clients FROM '/path/to/clients.csv' WITH (FORMAT csv, HEADER true);
```

**Via l'UI Supabase** : Table Editor → sélectionner table → **Insert → Import data from CSV**.

**Ordre d'import** (respecter les foreign keys) :
1. `depots`, `categories_produits`, `plan_comptable`, `exercices_comptables`
2. `fournisseurs`, `produits`, `clients`, `employes`
3. `commandes`, `commande_lignes`, `factures`, `paiements`
4. `bons_livraison`, `colis`, `livraisons`
5. Le reste

⚠️ Les colonnes `user_id` référencent `auth.users(id)`. Si vous recréez les users, les UUIDs vont changer — préparer un mapping.

## Option B — Supabase Self-hosted (avancé)

Setup complet : https://supabase.com/docs/guides/self-hosting/docker

**Prérequis** : VPS avec **8 GB RAM minimum**, Docker + Docker Compose, domaine.

```bash
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
# Éditer .env — changer TOUS les mots de passe et secrets JWT
docker compose up -d
```

Puis suivre les étapes 3-5 ci-dessus (les clés sont dans votre `.env`).

## Storage buckets

Recréer manuellement chaque bucket utilisé par l'application. Dans **Storage → New bucket** :
- Nom identique à l'ancien
- Public/privé selon le cas
- Ajouter les policies RLS (les recopier depuis votre code ou les migrations)

Buckets probables selon votre app :
- `documents` (PDF factures, bons de livraison)
- `avatars` ou `photos` (employés, produits)
- Vérifier dans le code : `grep -r "supabase.storage.from(" src/`

## Vérifications finales

```sql
-- Compter les tables
SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';
-- Attendu : ~97

-- Vérifier RLS
SELECT tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity = false;
-- Attendu : aucune ligne

-- Compter les policies
SELECT count(*) FROM pg_policies WHERE schemaname='public';
-- Attendu : plusieurs centaines

-- Compter les fonctions
SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public';
-- Attendu : ~260
```
