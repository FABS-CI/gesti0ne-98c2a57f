# 📦 Guide de migration ERP vers un autre hébergeur

Ce dossier contient tout ce qu'il faut pour héberger votre ERP en dehors de Lovable.

## 📋 Contenu

- **[01-checklist.md](./01-checklist.md)** — Checklist complète étape par étape
- **[02-architecture.md](./02-architecture.md)** — Architecture technique de l'application
- **[03-export-donnees.md](./03-export-donnees.md)** — Comment exporter code + base de données
- **[04-supabase-migration.md](./04-supabase-migration.md)** — Recréer le backend Supabase
- **[05-frontend-deploiement.md](./05-frontend-deploiement.md)** — Déployer le frontend (Vercel / VPS / Cloudflare)
- **[06-variables-environnement.md](./06-variables-environnement.md)** — Toutes les variables à configurer
- **[07-auth-oauth.md](./07-auth-oauth.md)** — Reconfigurer Google OAuth
- **[08-domaine-dns.md](./08-domaine-dns.md)** — Repointer le domaine
- **[09-post-migration.md](./09-post-migration.md)** — Tests et vérifications finales
- **[10-restauration-complete.md](./10-restauration-complete.md)** — Reconstituer l'ERP à partir des sauvegardes
- **[11-runbook-sauvegarde-restauration.md](./11-runbook-sauvegarde-restauration.md)** — Runbook hors ERP : sauvegarde, test de restauration, planning trimestriel
- **[.env.example](./.env.example)** — Modèle de fichier `.env` à remplir

## 🎯 Vue d'ensemble rapide

**Votre stack actuelle :**
- Frontend : TanStack Start v1 (SSR) + Vite + React 19 + Tailwind v4
- Backend : Supabase (PostgreSQL + Auth + RLS)
- Storage : Supabase Storage
- Server logic : `createServerFn` (TanStack) + fonctions SQL

**Ce qui doit être recréé chez le nouvel hébergeur :**
1. Projet Supabase (cloud ou self-hosted) — schéma + données + auth
2. Serveur applicatif Node.js/Edge (Vercel, Cloudflare Workers, VPS)
3. Google OAuth avec vos propres credentials
4. Variables d'environnement et secrets
5. Domaine + certificat SSL

**Durée estimée :** 1–2 jours pour un opérateur technique.

## ⚠️ Avant de commencer

- [ ] Faire une **sauvegarde complète** des données via Cloud → Advanced → Export
- [ ] Transférer le code sur **GitHub** (menu + → GitHub dans Lovable)
- [ ] Prévoir une **fenêtre de maintenance** (utilisateurs déconnectés pendant la bascule)
- [ ] Choisir l'hébergeur cible (voir `05-frontend-deploiement.md`)
- [ ] Créer un compte Supabase (ou préparer un VPS pour self-hosted)

## 🆘 Support

- Docs officielles Lovable self-hosting : https://docs.lovable.dev/tips-tricks/self-hosting
- Docs Supabase self-hosting : https://supabase.com/docs/guides/self-hosting
- Docs TanStack Start : https://tanstack.com/start
