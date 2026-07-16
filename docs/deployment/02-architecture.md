# 🏗️ Architecture technique

## Stack applicative

```
┌─────────────────────────────────────────────────────┐
│  Navigateur (utilisateur)                           │
└──────────────────┬──────────────────────────────────┘
                   │ HTTPS
┌──────────────────▼──────────────────────────────────┐
│  Frontend + SSR (TanStack Start)                    │
│  - React 19 + Vite 7                                │
│  - Tailwind CSS v4                                  │
│  - Server functions (createServerFn)                │
│  - Routes /api/public/* (webhooks)                  │
│  Runtime : Node.js 20+ OU Cloudflare Workers        │
└──────────────────┬──────────────────────────────────┘
                   │ HTTPS + Bearer token
┌──────────────────▼──────────────────────────────────┐
│  Supabase (backend)                                 │
│  - PostgreSQL 15 (~97 tables, ~260 RPC functions)   │
│  - Auth (email/password + Google OAuth)             │
│  - Row Level Security sur toutes les tables         │
│  - Storage (documents PDF, images)                  │
│  - Realtime (notifications)                         │
└─────────────────────────────────────────────────────┘
```

## Composants clés

### Frontend (`src/`)
- **`src/routes/`** — routes file-based TanStack Start
  - `_authenticated/` — routes protégées (RBAC)
  - `api/public/*` — endpoints publics (webhooks, cron)
- **`src/components/`** — composants React
- **`src/integrations/supabase/`** — clients Supabase (⚠️ auto-généré, ne pas modifier manuellement, sera régénéré)
- **`src/lib/`** — server functions (`*.functions.ts`) + helpers

### Backend Supabase (`supabase/migrations/`)
- **428 fichiers de migration SQL** (schéma + policies + fonctions RPC)
- Doivent être rejouées **dans l'ordre chronologique** sur le nouveau projet

### Modèle RBAC (Role-Based Access Control)
- Table `user_roles` (enum `app_role`) — rôles legacy simples
- Tables `rbac_roles`, `rbac_permissions`, `rbac_role_permissions`, `rbac_user_roles` — RBAC avancé avec hiérarchie
- Fonctions `has_role()`, `has_permission_v2()`, `assert_permission()` — vérification dans les RPC
- 260+ fonctions `SECURITY DEFINER` qui exécutent la logique métier

### Modules métier (tables principales)
| Module | Tables |
|---|---|
| CRM | clients, crm_interactions |
| Ventes | commandes, commande_lignes, proformas, factures, paiements |
| Livraisons | bons_livraison, colis, tournees, livsuivi_* |
| Stocks | produits, depots, stocks_depots, stock_mouvements, inventaires, transferts |
| Achats | fournisseurs, achats, approvisionnements |
| Comptabilité | plan_comptable, ecritures_comptables, ecriture_lignes, exercices |
| RH & Paie | employes, contrats, conges, absences, bulletins_paie |
| Système | audit_logs, notifications, backups, rbac_* |

## Dépendances externes (à vérifier)

- **Google OAuth** — sign-in
- **FNE** (facturation électronique) — table `fne_settings` avec potentielle API tierce
- **Lovable AI Gateway** — si utilisé pour chat/génération, à remplacer par OpenAI/Anthropic direct

## Runtime notes

- Le serveur applicatif tourne actuellement sur **Cloudflare Workers** (via Lovable)
- Compatible avec **Node.js 20+** pour les autres hébergeurs
- ⚠️ Certains packages Node-only (child_process, sharp, canvas) ne fonctionnent pas sur Cloudflare Workers — vérifier avant migration si vous restez sur Workers
