# Rapport d'audit sécurité

_Dernière mise à jour : 2026-07-04_

## 1. Findings corrigés

### Erreurs critiques (RLS trop permissives) — résolues

| Table | Ancienne policy | Nouvelle policy |
|---|---|---|
| `soldes_ouverture_fournisseurs` | `sof_select USING (true)` | `is_exercice_admin(auth.uid()) OR is_staff(auth.uid())` |
| `soldes_ouverture_clients` | `soc_select USING (true)` | `is_exercice_admin(auth.uid()) OR is_staff(auth.uid())` |
| `exercice_cloture_journal` | `ecj_select USING (true)` | `is_exercice_admin(auth.uid()) OR is_staff(auth.uid())` |

### Warnings résolus

| Table | Nouvelle policy |
|---|---|
| `tournees` | `is_staff(auth.uid())` |
| `colisage_responsables` | `is_staff(auth.uid())` |
| `preparateurs_colisage` | `is_staff(auth.uid())` |
| `exercices` | `is_staff(auth.uid()) OR is_exercice_admin(auth.uid())` |
| `rbac_roles` | `is_staff(auth.uid())` |
| `rbac_permissions` | `is_staff(auth.uid())` |

## 2. Warnings intentionnels (non corrigés — comportement voulu)

### 2.1 Fonctions `SECURITY DEFINER` exécutables par les rôles authentifiés (~68 findings)

**Décision : conservé.** Ce sont les RPC métier que l'application appelle via
PostgREST (`supabase.rpc(...)`). Chaque fonction contrôle elle-même les droits
via `assert_permission()`, `has_role()` ou `has_permission_v2()` avant toute
écriture. Révoquer `EXECUTE` casserait l'app.

Exemples :

- `creer_commande`, `modifier_commande`, `annuler_paiement`
- `enregistrer_paiement`, `payer_achat`, `receptionner_achat`
- `executer_cloture_exercice`, `preview_cloture_exercice`
- `creer_colisage`, `changer_statut_colis`, `livsuivi_*`

### 2.2 Fonctions publiques (`anon`) — 2 findings

- `get_carton_public(uuid)` : lecture d'un carton par lien QR public.
  Intentionnel — projection restreinte aux colonnes non sensibles.
- `bootstrap_first_super_admin()` : ne fonctionne QUE si aucun super admin
  n'existe encore ; devient no-op après le premier appel.

### 2.3 `Function Search Path Mutable` (6 findings)

Toutes les fonctions publiques ont pourtant `SET search_path = public` ou
`SET search_path = public, e2e_fixtures` (fixtures e2e). Le linter Supabase
lève encore quelques warnings sur fonctions triggers legacy. **Impact
négligeable** — pas d'usage d'objets non qualifiés à risque.

## 3. Risques restants (à surveiller)

| Domaine | Risque | Mitigation en place | Reste à faire |
|---|---|---|---|
| Auth email/password | Pas de HIBP check activé | — | Activer HIBP dans Cloud → Auth Settings |
| Fonctions e2e (`e2e_reset`, `e2e_seed`, ...) | Peuvent muter la base | `SECURITY DEFINER` + schéma `e2e_fixtures` isolé | Vérifier qu'elles ne sont **pas exposées** en production (retirer `GRANT EXECUTE TO anon, authenticated` si présent) |
| `bootstrap_first_super_admin` | Élévation initiale | No-op après 1er super admin | OK |
| Absence de journal d'audit centralisé sur RPC sensibles | Traçabilité limitée | Table `audit_events` + `log_audit_event()` disponibles, usage partiel | Ajouter triggers sur `annuler_*`, clôture, paiement |
| Tests RLS automatisés | Régression possible sur nouvelle policy | Script `supabase/tests/rls_permissions.sql` fourni | Intégrer en CI |

## 4. Prochaines étapes recommandées

1. Activer **HIBP Password Check** (Cloud → Users → Auth Settings).
2. Exécuter `supabase/tests/rls_permissions.sql` en CI avant chaque déploiement.
3. Ajouter `log_audit_event()` en fin de chaque RPC critique
   (`enregistrer_paiement`, `annuler_paiement`, `executer_cloture_exercice`).
4. Re-lancer le scan Supabase après chaque migration touchant les policies.
---

## Lot RLS-3 — Lectures sensibles (2026-07-30)

11 policies `SELECT USING (true)` remplacées par un contrôle de droit
(`has_permission_v2(...)` ou `super_admin`) :

| Tables | Droit requis |
|---|---|
| `approvisionnements`, `approvisionnement_lignes` | `achats.voir` |
| `fournisseurs` | `fournisseurs.voir` ou `achats.voir` |
| `couts_logistiques`, `couts_logistiques_audit` | `couts_logistiques.voir` |
| `soldes_ouverture_clients`, `soldes_ouverture_fournisseurs`, `exercice_cloture_journal` | `comptabilite.voir` ou `exercices.voir` |
| `fne_settings`, `fne_logs` | `fne.acceder_parametres` / `fne.voir` |
| `parametres_systeme` | `parametres.voir` |

Restent 49 lectures permissives sur des tables opérationnelles/référentielles
non sensibles (produits, commandes, colis, livraisons, transporteurs, RBAC v2
en lecture) — conservé volontairement pour ne pas casser les écrans partagés.

## Lot RLS-4 — Révocation de l'EXECUTE anonyme (2026-07-30)

`REVOKE EXECUTE ... FROM anon, PUBLIC` sur **69** fonctions `SECURITY DEFINER`
du schéma `public` (approbations, comptabilité, stock, RBAC, suppressions,
fonctions trigger). `GRANT` conservé pour `authenticated` et `service_role`.

Exception publique volontaire : `get_carton_public(uuid)` (lien QR carton,
projection non sensible) — `GRANT` explicite à `anon`.

Vérification : 0 fonction `SECURITY DEFINER` exécutable par `anon` hors cette
exception.

## Lot RLS-5 — search_path & extensions (2026-07-30)

- `search_path` fixé sur la dernière fonction concernée
  (`_compte_mode_paiement(text)`). Vérification : **0** fonction applicative du
  schéma `public` sans `search_path` figé ; les seules restantes appartiennent à
  l'extension `pg_trgm`.
- Warning « Extension in Public » (`pg_trgm`) : **conservé volontairement**.
  Déplacer l'extension invaliderait les classes d'opérateurs `gin_trgm_ops`
  utilisées par les index de recherche plein texte. Risque nul (fonctions
  d'extension sans accès aux données).
- Warnings « Signed-In Users Can Execute SECURITY DEFINER Function » (~180) :
  intentionnels — ce sont les RPC métier appelées par l'app, chacune protégée
  par `assert_permission()` / `has_permission_v2()` (cf. §2.1).

