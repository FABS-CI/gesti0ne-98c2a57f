# Lot unique — Centre d'Approbation + Workflow Retours v2

## Décisions actées

- **Rôles cumulés autorisés**, sauf combinaison interdite `commercial + comptable` (violation SoD, contrôlée à l'affectation et au runtime).
- **Verrouillage optimiste** via `version_no` sur `retours` et `workflow_approvals` (409 si conflit).
- **Notifications in-app + email** (Resend). SMS/WhatsApp = phase 2.
- **Audit permanent**, jamais purgé.
- **Migration auto** des retours existants (1 seul retour `accepte` en base → mappé `cloture`).

## Livrables

### 1. Base de données (migrations)

**a) Refonte `workflow_approvals` (moteur transversal)**
Ajout de colonnes : `module` (retours/paiements/couts_logistiques/annulation_facture/ecriture_manuelle), `niveau_urgence`, `sla_deadline`, `version_no`, `historique jsonb[]`, `pieces_jointes jsonb`, `simulation_financiere jsonb` (snapshot avant validation), `decision_details jsonb` (option comptable choisie + montants).
Nouveaux statuts unifiés : `en_attente` → `valide` | `refuse` | `complement_demande` → `cloture` | `annule`.

**b) Refonte `retours` (workflow 6 statuts)**
Statuts stricts : `demande_creee` → `attente_reception` → `receptionne` → `attente_validation_compta` → `valide_compta` → `cloture`. Branches : `refus_magasin`, `refus_compta`, `annule`.
Ajout `receptionne_par`, `receptionne_at`, `valide_compta_par`, `valide_compta_at`, `version_no`, `workflow_approval_id`.
Ajout sur `retour_lignes` : `quantite_demandee`, `quantite_recue`, `etat_reception` (conforme/endommage/refuse), `commentaire_reception`.

**c) RLS resserrée**
Remplacement des `USING (true)` sur retours par policies scindées :
- `SELECT` : tout authentifié
- `INSERT` : `has_permission('retours.creer')`
- `UPDATE` : `has_permission('retours.receptionner')` OU `has_permission('retours.valider_compta')` OU `has_permission('retours.annuler')` selon transition (contrôlé par RPC)

**d) Nouvelles permissions RBAC**
`retours.receptionner`, `retours.refuser_magasin`, `retours.valider_compta`, `retours.refuser_compta`, `retours.forcer_cloture`, `approbations.voir`, `approbations.valider`, `approbations.refuser`, `approbations.forcer`, `approbations.rouvrir`.
Affectation aux rôles existants : Commercial / Gestionnaire stock / Comptable / Assistante comptable / Super Admin.

**e) Contrainte SoD**
Trigger sur `rbac2_user_roles` bloquant l'affectation simultanée `commercial` + `comptable` au même utilisateur.

**f) RPC transactionnelles (une par transition, `SECURITY DEFINER` + `has_permission` interne)**
- `retour_creer_demande(payload)` → statut `demande_creee` + insert `workflow_approvals` (module=`retours`, statut=`en_attente` côté magasin)
- `retour_receptionner(retour_id, lignes, version_no)` → transaction : maj lignes reçues, mvts stock, `stocks_depots`, statut `receptionne` → auto-transition `attente_validation_compta` + création approbation compta
- `retour_refuser_magasin(retour_id, motif, version_no)`
- `retour_simulation_financiere(retour_id)` (lecture pure) → renvoie facture, TVA, payé, restant, historique paiements, lignes retournables, impacts calculés
- `retour_valider_compta(retour_id, option, montants, version_no)` où `option ∈ (diminuer_solde|creer_avoir|preparer_remboursement|aucun_impact)` → transaction unique : écritures compta, avoir si demandé, maj solde client, historique, statut `cloture`
- `retour_refuser_compta(retour_id, motif, version_no)`
- `retour_forcer_cloture(retour_id, motif)` (super_admin)
- `approbation_valider/refuser/complement/forcer/rouvrir` (génériques)

Chaque RPC : contrôles métier (facture non annulée, exercice ouvert, quantités ≤ retournables, doublons), verrou optimiste (raise si `version_no` ne matche pas), écriture audit détaillée (ancien/nouveau, IP via `inet_client_addr()`), insert notifications.

**g) Migration des retours existants**
`UPDATE retours SET statut = CASE statut WHEN 'accepte' THEN 'cloture' WHEN 'en_cours' THEN 'attente_reception' ELSE statut END` + création rétroactive d'un `workflow_approvals` clôturé pour chaque retour existant.

### 2. Server functions

Fichiers `src/lib/retours-v2.functions.ts` et `src/lib/approbations.functions.ts` — chacun avec `.middleware([requireSupabaseAuth])`, appel des RPC ci-dessus, mapping vers DTO client. Gestion 409 (conflit version) → toast dédié.

### 3. Frontend

**Routes**
- `/_authenticated/retours` (liste, filtres par statut/module/dépôt/période)
- `/_authenticated/retours/nouveau` — formulaire Commercial (existant, adapté au nouveau flux)
- `/_authenticated/retours/$retourId` — écran unifié avec sections dynamiques selon rôle/statut
- `/_authenticated/retours/$retourId/receptionner` — écran Gestionnaire stock
- `/_authenticated/approbations` — refonte complète (Centre d'Approbation)
- `/_authenticated/approbations/$approvalId` — écran générique 4 sections (Infos / Situation facture / Articles / Simulation financière) + boutons contextuels par rôle

**Composants**
- `<WorkflowStatusBadge>` (6 statuts + refus/annule)
- `<WorkflowTimeline>` (historique visuel)
- `<SimulationFinancierePanel>` (section 4 du cahier)
- `<ValidationCompaDialog>` (choix option + popup confirmation + récap montants)
- `<ReceptionRetourForm>` (contrôle qté/état ligne à ligne)
- `<ApprobationCenterTable>` (tableau de bord filtrable multi-modules)
- `<RaccourciApprobationsCard>` sur dashboard (compteur "En attente pour vous")

Boutons visibles/désactivés dynamiquement via `usePermissions()` + état du dossier (mapping strict cahier §5.5).

### 4. Notifications

Extension de `notifications` + trigger DB : à chaque transition, insert notifications ciblées (commercial du dossier / gestionnaires stock / comptables / super admins) avec deep-link vers l'écran d'approbation. Email transactionnel via Resend (template par type).

### 5. Audit

Écritures dans `audit_logs` à chaque RPC : user, rôle, IP, ancien statut, nouveau statut, payload, motif, deep-link. Vue `v_retours_audit` pour affichage timeline.

## Plan de tests inclus

Suite `supabase/tests/retour_workflow.test.sql` couvrant : retour simple/partiel/total/multiple, refus magasin, refus compta, double validation bloquée, conflit `version_no`, utilisateur non autorisé, rollback (simulation d'erreur en cours de validation compta), SoD (commercial+comptable rejeté), migration des retours existants.

## Détails techniques

```text
Flux runtime d'une validation comptable
─────────────────────────────────────────
Client → useServerFn(retour_valider_compta)
       → attachSupabaseAuth (bearer)
       → RPC retour_valider_compta(_id, _option, _montants, _version)
           BEGIN
             SELECT ... FOR UPDATE (retour)
             IF version_no != _version → RAISE 'CONFLICT'
             IF NOT has_permission('retours.valider_compta') → RAISE
             IF exercice fermé → RAISE
             INSERT ecritures_comptables + ecriture_lignes
             IF option='creer_avoir' → INSERT facture (type=avoir)
             UPDATE compte client (solde)
             UPDATE retours SET statut='cloture', version_no+=1
             UPDATE workflow_approvals SET statut='valide'
             INSERT audit_logs + notifications
           COMMIT (ou ROLLBACK complet)
       → Client invalide queries (retours, dashboard, etat_compte)
```

Ordre d'exécution : (1) migration DB → approbation utilisateur → (2) types Supabase régénérés → (3) server functions + frontend → (4) tests SQL → (5) publication.

**Durée estimée** : ~2h de génération, changements sur ~35 fichiers, 1 migration lourde.

Confirmez pour que je lance la migration DB en premier.
