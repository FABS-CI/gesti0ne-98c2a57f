# Audit performance runtime — FABS-CI ERP
_Généré : 2026-07-20 · Base : `pg_stat_statements` (7j), `perf_web_vitals`, `perf_query_log`, `db_health`._

## 1. Verdict global

- **Base de données : saine.** 25.9 MB, mémoire 67%, disque 15%, 39/60 connexions, 0 redémarrage. **Ce n'est pas le backend qui rame.**
- **Le goulot est côté frontend + réseau**, pas côté Postgres. Les temps d'exécution SQL sont <10 ms partout ; les 150–200 ms observés sont **RLS + PostgREST + latence réseau**.
- **Un point noir Web Vitals critique** : `/commandes` avec un LCP de **17 s** (P75) — inacceptable.

---

## 2. Top signaux objectifs

### 2.1 Web Vitals (P75, 7j)

| Route | LCP | FCP | TTFB | Verdict |
|---|---|---|---|---|
| `/commandes` | **17 128 ms** 🔴 | 16 212 ms | 2 094 ms | **Critique** |
| `/colisage/:id` | 3 932 ms 🟠 | 2 568 ms | 1 218 ms | À traiter |
| `/logistics-costs` | 3 804 ms 🟠 | 2 620 ms | 3 729 ms | À traiter |
| `/carton/:id` | 3 819 ms 🟠 | 3 006 ms | 2 058 ms | À traiter |
| `/etat-compte-clients` | — | — | **4 055 ms** 🔴 | Serveur lent |
| `/fne` | — | — | 3 520 ms 🟠 | Serveur lent |
| `/auth` | 1 292 ms 🟢 | 1 082 ms | 2 063 ms 🟠 | OK sauf TTFB |

**Cibles Google :** LCP <2500 ms, FCP <1800 ms, TTFB <800 ms, INP <200 ms.

### 2.2 Requêtes SQL les plus coûteuses (cumul 7j)

| # | Requête | Calls | Mean | Total | Note |
|---|---|---|---|---|---|
| 1 | `clients WHERE actif=true ORDER BY created_at LIMIT` | 123 | **159 ms** | 19 545 ms | **Fiche 360 / listing** |
| 2 | `clients SELECT id,nom,tel,plafond,repr ORDER BY nom` | 116 | 81 ms | 9 369 ms | Sélecteurs autocomplete |
| 3 | `clients SELECT * LIMIT/OFFSET (sans WHERE)` | 40 | 164 ms | 6 555 ms | Export ou pagination brute |
| 4 | `clients WHERE nom/ref/repr ILIKE ... AND actif` | 30 | 149 ms | 4 477 ms | Recherche multi-colonnes |
| 5 | `dashboard_client_stats()` RPC | 140 | 28 ms | 3 960 ms | OK |
| 6 | `user_roles WHERE user_id=$1` | **23 570** 🔴 | 0.08 ms | 1 912 ms | **Volume anormal** |
| 7 | `profiles WHERE id=$1 SELECT actif` | 1 077 | 0.4 ms | 418 ms | Actif-gate polling |
| 8 | `notifications ORDER BY date` | 575 | 0.6 ms | 329 ms | OK |
| 9 | `incident_alerts WHERE resolved=false` | 1 445 | 0.2 ms | 244 ms | Polling banner |
| 10 | `v_produits WHERE actif ORDER BY pin,niveau,titre` | 104 | 4 ms | 376 ms | OK |

### 2.3 Santé BDD

- Rolled-back transactions cumul : **7 764** — élevé. Indique des RPC qui échouent après début de transaction (validations trop tardives, contraintes, RLS refusée).
- `audit_logs` : 2 708 lignes (4.6 MB). Croissance rapide sans purge → surveiller.
- Connexions 39/60 (65%). Marge OK.

---

## 3. Diagnostic ciblé

### 🔴 P1 — `/commandes` LCP 17 s
- Requête SQL derrière = <10 ms ; le budget est brûlé côté **JavaScript**.
- Causes probables (à confirmer en profilage) :
  1. Bundle client d'entrée trop gros (fetcher React + composants importés statiquement au lieu d'être lazy).
  2. Chargement en cascade : loader → composant → 3-4 `useQuery` déclenchés séquentiellement.
  3. Table lourde sans virtualisation avec calculs coûteux par ligne (statuts, badges, tri client).

### 🔴 P2 — `user_roles` interrogé 23 570 fois en 7j
- ~140 calls/heure pour ~10 utilisateurs → ~14 lectures/heure/user.
- Le cache RBAC introduit lors du Lot C3 ne couvre pas `user_roles` directement. Toute mutation invalide, et `useAuth`/`Can`/`RouteGuard` re-listent au montage.

### 🔴 P3 — Requêtes `clients` répétées à 150 ms
- Postgres exécute en 5 ms (voir EXPLAIN `Index Scan on idx_clients_actif_created_at`).
- **145 ms perdus** dans : RLS (auth.uid() + `has_permission`), sérialisation PostgREST, TLS, latence Abidjan↔Cloud.
- Le seul moyen de gagner ici : **réduire la fréquence** (cache plus long, dedup, ne pas recharger la liste complète à chaque focus).

### 🟠 P4 — `/etat-compte-clients` TTFB 4 s
- Le loader route lance probablement une agrégation multi-clients server-side (server fn) synchrone.
- Optimisation existante récente : requête globale + cache 60 s. À vérifier qu'elle est bien active en prod (pas d'invalidation intempestive).

### 🟠 P5 — `profiles.actif` polling 1 077x/7j
- Provient de `ActifGate` monté par route et non mémoïsé au niveau layout.

### 🟠 P6 — `incident_alerts` polling 1 445x/7j
- Bannière système polle (probablement `refetchInterval`). Chaque call est <1 ms mais génère du bruit.

---

## 4. Recommandations classées ROI/effort

| # | Action | Route/module | Effort | Gain attendu | Prio |
|---|---|---|---|---|---|
| A | **Profil de bundle `/commandes` + lazy-load des colonnes lourdes + virtualisation** | `/commandes` | 45 min | LCP 17 s → <3 s | 🔴 P0 |
| B | **Cache `user_roles` sur `useAuth` + broadcast realtime** (invalider seulement sur `rbac_role_permissions` change) | Global | 30 min | −90% calls user_roles | 🔴 P0 |
| C | **Hoister `ActifGate` dans le layout `_authenticated`** (une seule query par session) | Global | 15 min | −95% calls profiles | 🟠 P1 |
| D | **Loader parallélisé `/etat-compte-clients`** (Promise.all + streaming Suspense) | `/etat-compte-clients` | 30 min | TTFB 4 s → <1 s | 🟠 P1 |
| E | **`refetchInterval` → realtime subscribe** sur `incident_alerts` | Bannière | 15 min | −99% calls | 🟢 P2 |
| F | **Retention `audit_logs`** : purge >90j via pg_cron | DB | 20 min | Empêche dérive future | 🟢 P2 |
| G | **Investiguer les 7 764 txn rolled-back** — logs RPC échouées | DB | 45 min | Fiabilité + support | 🟠 P1 |
| H | **Coalescer `clients` autocomplete** (une seule query partagée entre sélecteurs sur la même page) | Formulaires | 30 min | −40% calls clients | 🟢 P2 |

---

## 5. Ce que je propose comme suite

**Séquence recommandée :**

1. **A + B en priorité** (~1h15) — traite les deux points visibles à l'utilisateur (`/commandes` bloqué + polling RBAC).
2. **C + D** (~45 min) — supprime les polls parasites et accélère l'état de compte.
3. **G** (~45 min) — investigation qualitative des rollbacks.
4. Puis **refactor arbo (A + B + D)** demandé précédemment.

**Alternative** : je démarre **immédiatement le refactor arbo** et on planifie A+B+C+D en Lot Perf séparé demain.

Réponds : `perf d'abord` (je fais A+B maintenant), `arbo d'abord`, ou `A+B+C+D en un lot` (~2h).
