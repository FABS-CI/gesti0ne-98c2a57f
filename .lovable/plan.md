# Refonte RBAC v2 — inspirée Odoo Enterprise

Livraison **phasée** en 3 itérations. Chaque phase est validable indépendamment ; l'ancien module `rbac_*` reste **en lecture** pour rollback jusqu'à la fin de la Phase 3.

---

## Modèle de données (schéma v2, nouvelles tables)

Nouvelles tables (l'ancien `rbac_permissions` / `rbac_roles` / `rbac_user_roles` / `rbac_role_permissions` reste intact) :

```text
rbac2_domains         (code, label, icon, sort)                          -- Commercial, Stocks, Compta...
rbac2_modules         (code, domain_code, label, icon, sort)             -- Catalogue, Factures, Dépôts...
rbac2_resources       (code, module_code, label, kind, route|rpc|null)   -- 1 écran / 1 RPC / 1 export
rbac2_permissions     (code UNIQUE, resource_code, action, label)        -- resource:action
rbac2_perm_deps       (perm_code, requires_code)                         -- dépendances auto
rbac2_roles           (code, label, description, is_system, sort)
rbac2_role_parents    (role_code, parent_code)                           -- héritage MULTIPLE
rbac2_role_perms      (role_code, perm_code, granted bool)               -- grant explicite / deny
rbac2_user_roles      (user_id, role_code, granted_by, granted_at)
rbac2_audit           (actor_id, action, target_type, target_id, before jsonb, after jsonb, ip, at)
```

- `action` ∈ voir, creer, modifier, supprimer, valider, annuler, approuver, refuser, cloturer, exporter_pdf, exporter_excel, imprimer, importer, restaurer, archiver, deverrouiller, admin (+ actions métier détectées).
- `has_permission_v2(user, perm_code)` = SECURITY DEFINER qui résout héritage multiple (fermeture transitive via récursif CTE) + deny explicite prioritaire.
- Fonction de compat `has_permission()` (ancien nom) : d'abord v2, fallback v1 pendant migration.

Grants standards (`authenticated` + `service_role`). RLS : lecture pour tous authentifiés, écriture réservée à `has_permission_v2(auth.uid(), 'rbac:admin')`.

---

## Phase 1 — Fondation & UI Odoo-like (livrable immédiat)

**Backend**
- Migration créant les 10 tables + `has_permission_v2` + trigger audit.
- Seed initial du **catalogue** : domaines, modules, ressources et permissions dérivés du `nav-data.ts` existant + liste RPC actuels (extraction via `psql` sur `pg_proc`) + routes `src/routes/_authenticated/*`.
- Seed des rôles système : `super_admin`, `admin`, `directeur_general`, `directeur_commercial`, `commercial`, `comptable`, `magasinier`, `rh`, `preparateur`, `livreur`, `employe` avec parents.
- Migration des attributions actuelles `rbac_user_roles` → `rbac2_user_roles` (mapping par code).

**Frontend** — nouvelle route `/_authenticated/admin/roles-v2`
- Layout 3 colonnes type Odoo : liste rôles ↔ arbre permissions ↔ panneau détails.
- Arbre permissions replié par **domaine > module > ressource** avec compteur, barre de progression, icônes.
- Recherche instantanée + filtres (action, domaine, type).
- Fiche rôle : résumé, nb utilisateurs, permissions accordées / refusées / héritées (badges de couleur), parents multiples éditables.
- Attribution rôle→user avec récapitulatif modal (modules accessibles, menus visibles, restrictions) avant validation.

**Compatibilité**
- Ancien menu Admin > Rôles conservé, badge "v1 (lecture seule)".
- Nouveau menu Admin > **Rôles & Permissions**.

---

## Phase 2 — Dépendances & Diagnostic (itération suivante)

- Éditeur graphique de dépendances (`Créer facture` ⇒ `Voir clients`, `Voir produits`…).
- Résolution auto : cocher une perm coche ses `requires` (visuellement grisées, décochables uniquement en retirant la parente).
- **Moteur de diagnostic** : orphelines, doublons, conflits, menus sans perm, routes non protégées, RPC non sécurisés. Rapport avec propositions de correction (non appliquées auto).
- Journal d'audit consultable avec filtres + export CSV.

---

## Phase 3 — Synchronisation automatique (itération finale)

- Bouton **Synchroniser** : scan runtime de `nav-data.ts`, du router (`routeTree.gen.ts`), des RPC (`pg_proc`) et de la table `rbac2_resources`.
- Diff visuel : nouvelles ressources détectées, obsolètes, non couvertes.
- Création des permissions manquantes en un clic, sans toucher aux personnalisations.
- Retrait/archivage de l'ancien module `rbac_*` après validation utilisateur.

---

## Détails techniques

- **Héritage multiple** résolu côté SQL par CTE récursive dans `has_permission_v2`, cache client (`use-user-permissions-v2`) 10 min avec invalidation Realtime sur `rbac2_role_perms`, `rbac2_user_roles`, `rbac2_role_parents`.
- **Deny explicite** > grant hérité > grant direct.
- **Audit** : trigger AFTER INSERT/UPDATE/DELETE sur `rbac2_role_perms`, `rbac2_user_roles`, `rbac2_roles`, `rbac2_role_parents` → écrit dans `rbac2_audit` avec `auth.uid()` et `inet_client_addr()`.
- **Serveur** : fonction serveur `sync_rbac_catalog` (Phase 3) qui reçoit l'inventaire calculé côté client (routes + RPC + menus) et upsert dans `rbac2_resources`.
- **Zéro breaking** : les composants qui appellent `has_permission(code)` continuent de fonctionner grâce à la fonction de compat.

---

## Ce qui n'est PAS inclus (par choix)

- Analyse AST profonde des `.tsx` pour extraire chaque `<Button>` : trop fragile, remplacé par la déclaration explicite `resources` + sync Phase 3.
- Génération auto de composants `<Can permission="…">` sur chaque bouton existant : nécessiterait refactor massif — proposé en Phase 4 optionnelle.
- Rétrocompatibilité des composants `use-user-roles` : conservés, alimentés par v2 via la fonction de compat.

---

## Prochaine étape

Sur validation, je démarre **Phase 1** = migration SQL + seed + nouvelle console `/admin/roles-v2`. Environ 5-8 messages successifs (migration → seed → UI liste rôles → UI arbre perms → UI détails/attribution → tests).
