# Monitoring & Alertes — Production

## 1. Erreurs UI (client)
- Boundary racine : `ErrorComponent` dans `src/routes/__root.tsx`.
- Reporter : `reportLovableError` (`src/lib/lovable-error-reporting.ts`) — remonte automatiquement chaque exception non catchée vers Lovable Cloud.
- Vérifier : Lovable → Analytics → Errors.

## 2. Logs serveur (server functions & DB)
- Server functions : logs accessibles via `stack_modern--server-function-logs`.
- Base de données : requêtes lentes via `supabase--slow_queries` (surveillance hebdo recommandée).
- Santé instance : `supabase--db_health` (mémoire, disque, connexions).

## 3. Performances clés
- `defaultPreload: "intent"` + `staleTime: 30s` (déjà actif).
- Index GIN trigram sur clients/produits/commandes (migrations appliquées).
- Bundle : `jspdf`, `xlsx`, `recharts`, `dnd-kit` en lazy-load.

## 4. Alertes recommandées (à activer manuellement)
| Signal | Seuil | Action |
|---|---|---|
| Erreurs UI > 10 / 5 min | Critique | Rollback (History) |
| Requête DB > 1 s (P95) | Warning | Ajouter index / EXPLAIN ANALYZE |
| Disque DB > 80% | Critique | Nettoyage `audit_logs`, upgrade instance |
| Login failed > 20 / min | Sécurité | Vérifier bruteforce, activer captcha |

## 5. Checklist déploiement
- [x] Security scan : 0 findings critiques
- [x] `LOVABLE_API_KEY` provisionnée
- [x] Publish visibility : public
- [x] Migrations DB à jour (126)
- [x] `defaultErrorComponent` router configuré

## 6. Rollback
History → sélectionner la version stable précédente → Restore.
Les données ne sont pas affectées (les migrations DB ne rollback pas automatiquement).