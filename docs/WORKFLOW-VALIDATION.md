# Workflow de validation (Odoo-like)

## Objectif

Fournir un pattern **réutilisable** pour tout module ERP nécessitant une
validation à deux étapes basée sur les permissions RBAC v2.

## Contrat serveur

Pour un module `<mod>` :

| Élément | Rôle |
|---|---|
| Permission `<mod>.creer` | Autorise la création (état initial = `en_attente_validation`) |
| Permission `<mod>.valider` | Autorise la transition `en_attente_validation → valide` et l'auto-validation à la création |
| RPC `creer_<mod>(_payload jsonb)` | `assert_permission('<mod>.creer')` + auto-validation si `has_permission_v2(auth.uid(),'<mod>.valider')` |
| RPC `valider_<mod>(_id uuid, _commentaire text)` | `assert_permission('<mod>.valider')` + transition + log audit |
| RPC `rejeter_<mod>(_id uuid, _motif text)` | `assert_permission('<mod>.valider')` + motif obligatoire (≥3 car.) + log audit |
| Colonnes d'audit | `valide_par uuid`, `valide_le timestamptz`, `rejete_par uuid`, `rejete_le timestamptz`, `motif_rejet text`, `commentaire_validation text`, `cree_par uuid` |
| Trigger `trg_<mod>_enforce_validation` (BEFORE INSERT) | Force le statut selon la permission de l'utilisateur (défense en profondeur si l'INSERT court-circuite la RPC) |

Toutes les transitions sont journalisées dans `rbac_audit_log` avec action `'<mod>_valide'` ou `'<mod>_rejete'`.

## Contrat client

- Hook `use<Module>EnAttente()` — liste des enregistrements en attente
- Hook `useValider<Module>()` — mutation React Query
- Hook `useRejeter<Module>()` — mutation avec motif
- Composant `<Module>EnAttenteCard` wrappé dans `<Can permission="<mod>.valider">`
- Composant `Rejeter<Module>Dialog` — motif obligatoire
- Toast adaptatif à la création : `usePermissions().has('<mod>.valider')` choisit entre « créé et validé » et « en attente de validation »

## Modules implémentés

### Commandes (existant, amélioré)

- Statuts : `brouillon` → `en_attente_validation` → `validee` → `livree` / `annulee`
- RPC `creer_commande` — auto-validation si permission ✅
- RPC `valider_commande` — transition, avec impact stock + facture + BL
- Bouton "Valider" masqué via `canValider` dans `CommandeRow`

### Paiements (nouveau — Lot 2)

- Statuts : `en_attente_validation` → `valide` → `annule` / `rejete`
- Aucun impact fidélité ni comptable tant que `statut = 'en_attente_validation'`
- Trigger BEFORE INSERT `trg_paiements_enforce_validation` force le statut
- RPC `valider_paiement(_id, _commentaire)` et `rejeter_paiement(_id, _motif)`
- Composant `PaiementsEnAttenteCard` intégré dans `/paiements`

### Roadmap : modules candidats

- Congés (`conges.valider` déjà en base)
- Achats / Bons de commande fournisseur
- Factures (validation avant émission)
- Retours / Avoirs

## Attribution par défaut

| Rôle | `commandes.valider` | `paiements.valider` |
|---|:---:|:---:|
| Super Administrateur | ✅ | ✅ |
| Direction Générale | ✅ | ✅ |
| Comptabilité | ✅ | ✅ |
| Assistante Comptable | ❌ | ❌ |
| Direction Commerciale | ✅ (à confirmer) | ❌ |
| Autres rôles | ❌ | ❌ |

La matrice reste modifiable dans `/roles-permissions` (Super Admin uniquement).