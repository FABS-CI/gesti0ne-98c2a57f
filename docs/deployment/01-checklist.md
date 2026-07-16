# ✅ Checklist de migration

## Phase 1 — Préparation (avant coupure)

- [ ] Connecter Lovable à GitHub (menu + → GitHub → Create Repository)
- [ ] Cloner le dépôt en local : `git clone <url>`
- [ ] Vérifier que `bun install` puis `bun run build` fonctionnent en local
- [ ] Exporter les données depuis Cloud → Advanced settings → Export data
- [ ] Récupérer la liste des **secrets** utilisés (voir `06-variables-environnement.md`)
- [ ] Choisir l'hébergeur frontend (Vercel recommandé, ou VPS)
- [ ] Créer un projet Supabase (cloud ou self-hosted)
- [ ] Créer un projet **Google Cloud Console** pour OAuth (Client ID + Secret)

## Phase 2 — Reconstruction du backend

- [ ] Récupérer l'URL et les clés du nouveau Supabase (`SUPABASE_URL`, publishable key, service role key)
- [ ] Rejouer toutes les migrations SQL du dossier `supabase/migrations/` (voir `04-supabase-migration.md`)
- [ ] Vérifier que **RLS est activé** sur toutes les tables `public.*`
- [ ] Vérifier les **GRANTS** (authenticated, service_role, éventuellement anon)
- [ ] Importer les données exportées (CSV → tables ou dump SQL)
- [ ] Créer les **buckets Storage** nécessaires (si utilisés)
- [ ] Configurer Auth → Providers → Google (Client ID + Secret depuis Google Cloud)
- [ ] Configurer Auth → URL Configuration (Site URL + Redirect URLs)
- [ ] Activer HIBP password protection (Auth → Providers → Email)

## Phase 3 — Déploiement frontend

- [ ] Créer projet sur Vercel/Netlify/Cloudflare Pages (ou provisionner VPS)
- [ ] Configurer les variables d'environnement (voir `.env.example`)
- [ ] Lancer le premier build
- [ ] Corriger les erreurs éventuelles (imports serveur, secrets manquants)
- [ ] Tester la première URL de preview
- [ ] Vérifier login email + Google
- [ ] Vérifier CRUD principales (commandes, factures, stocks, employés)

## Phase 4 — Bascule production

- [ ] Prévenir les utilisateurs (fenêtre de maintenance)
- [ ] Faire un dernier export des données depuis Lovable Cloud
- [ ] Réimporter la version fraîche dans le nouveau Supabase
- [ ] Repointer le domaine (`gesti0ne.com` ou autre) vers le nouvel hébergeur
- [ ] Attendre propagation DNS (jusqu'à 72h)
- [ ] Vérifier certificat SSL
- [ ] Vérifier `/api/public/*` (webhooks/cron)
- [ ] Reconfigurer les cron externes (pg_cron ou scheduler) avec la nouvelle URL

## Phase 5 — Post-migration

- [ ] Monitorer les erreurs 24-48h (logs serveur + Supabase logs)
- [ ] Vérifier les sauvegardes automatiques Supabase
- [ ] Documenter le nouveau setup pour votre équipe
- [ ] Conserver l'ancien Lovable Cloud 1 semaine en lecture seule (au cas où)
- [ ] Après validation : supprimer/archiver le projet Lovable
