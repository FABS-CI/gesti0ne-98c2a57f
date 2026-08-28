# AUDIT ERP — SIMPLIFICATION ET STRUCTURATION

Audit **strictement en lecture seule**. Aucun fichier applicatif, schéma, migration ou test n'a été modifié.
Périmètre : 8 domaines audités en parallèle (RBAC/Auth, Ventes/Facturation, Stock/Achats, Logistique/Colisage,
Comptabilité/Trésorerie, PDF/Documents, Audit/Recherche/Export, Plateforme/RH-Paie).

---

## 1. Synthèse

| # | Recommandation | Domaine | Verdict | Confiance | Priorité |
|---|---|---|---|---|---|
| R1 | Mapping cassé `compta_balance` → TypeScript (balance, FEC, dashboard compta faussés) | Comptabilité | CORRIGER | HIGH | **P0** |
| R2 | Triggers d'audit legacy dupliqués (double/triple écriture par événement CRUD) | Audit | CORRIGER | HIGH | **P1** |
| R3 | Écritures directes mortes `createFacture/updateFacture/createPaiement/updatePaiement` | Ventes | SUPPRIMER | HIGH | **P1** |
| R4 | Moteur de paie orphelin `calculateBulletin.ts` (taux figés divergents) | RH/Paie | SUPPRIMER | HIGH | **P1** |
| R5 | Faux « backup complet » sur `/exports` + 2 pipelines d'export concurrents | Export/Backup | CORRIGER | HIGH | **P1** |
| R6 | 6 réimplémentations SQL du pattern d'écriture stock hors `ajuster_stock_depot` | Stock | CENTRALISER | MEDIUM | **P2** |
| R7 | Invalidation de cache RH incomplète et divergente | RH/Plateforme | CORRIGER | MEDIUM | **P2** |
| R8 | Façade `fabsTemplates.ts` ↔ `unified-generator.ts` (indirection + dépendance circulaire) | PDF | FUSIONNER | HIGH | **P3** |
| — | PDF Incidents = stub renvoyant un Blob vide (anomalie signalée, hors format simplification) | PDF | BUG séparé | HIGH | **P1 (bug)** |

SKIP motivés (aucune action recommandée) : doublon d'expansion `.voir` RBAC, coexistence `has_permission_v2`/`rbac3_can`,
duplication de calcul de totaux commande (preview UX vs RPC faisant autorité), colisage/étiquetage (pipeline unique vérifié),
machine à états tournées/livraisons, coexistence jsPDF/pdf-lib (documentée et volontaire), `ecritureEquilibree` (test-only),
empilement de migrations RH (preuve insuffisante).

---

## 2. Inventaire des sous-systèmes

### RBAC & Auth
AUTH-01 Session Supabase · RBAC-02 Permissions v3 (RPC `rbac3_permissions_of`) · RBAC-03 Pont v3→v2 (`rbac3-bridge.ts`) ·
RBAC-04 Normalisation `.voir` legacy · RBAC-05 Catalogue codes · RBAC-06 Gates UI (`Can`, `ActifGate`) ·
RBAC-07 `RouteGuard` + `route-permissions.ts` · RBAC-08 Rôles legacy `user_roles` · RBAC-09 Admin rôles (Tab/TabV3) ·
RBAC-10 Server functions `requireSupabaseAuth` · RBAC-11 ~41 migrations RBAC · RBAC-12 Diagnostics menu.

### Ventes & Facturation
V1 Commandes (RPC `creer_commande`, `valider_commande`, conversions) · V2 `CommandeForm` (859 l.) ·
V3 Factures (`factures-api.ts`, `@ts-nocheck`) · V4 Paiements · V5 `paiement-recap.ts` (pur) ·
V6 `facturation-workflow.ts` (pur) · V7 PDF commerciaux · V8 Clients · V9 Fournisseurs · V10 Finances.

### Stock, Achats & Produits
S1 Produits · S2 Dépôts · S3 Stock (`stocks_depots` = table de vérité) · S4 Inventaires · S5 Achats · S6 Sorties stock (ventes/colisage).
Ownership vérifié : le décrément a lieu à `valider_commande`, jamais au colisage — **pas de double mouvement**.

### Logistique & Colisage
L1 Colisage (RPC unique `creer_colisage_manuel`) · L2 Étiquetage (`etiquette-html.ts` + `print-etiquettes.ts`, pipeline unique) ·
L3 Tournées · L4 Livraison-suivi (`LivStatut` union stricte) · L5 Retours (testé) · L6 BL/Expéditions.

### Comptabilité & Trésorerie
CPT-01 API lecture (**défaillant**) · CPT-02 Helpers journal · CPT-03 Validateurs purs · CPT-04 Écritures auto (triggers, idempotents via `piece_ref`) ·
CPT-05 Garde-fous d'équilibre · CPT-06 Exercices/clôture · CPT-07 FEC · CPT-08 États comptables.

### PDF & Documents
DOC-01 Façade `fabsTemplates.ts` (26 appelants) · DOC-02 Moteur pdf-lib V10 · DOC-03 Moteur jsPDF (rapports) ·
DOC-04 Enrichissement `enrich-lignes.ts` · DOC-05 Numérotation (hors périmètre PDF) · DOC-06 Modèles ·
DOC-07 Vérification/QR · DOC-08 Centre de documents · DOC-09 Chrome HTML · DOC-10 FNE · DOC-11 Incidents (**cassé**).

### Audit, Recherche, Export
S1 Audit client · S2 Audit server · S3 Triggers DB (**2 systèmes coexistants**) · S4 Notifications · S5 Recherche globale ·
S6 Dashboards (agrégation SQL via RPC — bonne pratique) · S7 Import/Export (**2 moteurs**) · S8 Backup serveur.

### Plateforme & RH
S1 Bootstrap TanStack · S2 Routes API publiques · S3 Intégrations Supabase · S4 Erreurs · S5 Cache-invalidation (RH absent) ·
S6 Realtime · S7 Perf/Idempotency · S8 593 migrations · S9 Moteur paie `engine.ts` · S10 `calculateBulletin.ts` (**mort**) ·
S11 RH API · S12 Routes RH.

---

## 3. Recommandations détaillées

### R1 — Mapping de champs cassé entre le RPC `compta_balance` et son consommateur TS
**Verdict** : CORRIGER · **Sous-système** : CPT-01 · **Fichiers** : `src/lib/compta-api.ts:79-99`

1. **Évidence** : le RPC retourne `numero_compte, libelle, debit, credit, solde` (`supabase/migrations/20260717100712_*.sql:144-167`,
   confirmé par `src/integrations/supabase/types.ts:7220-7229`), mais `compta-api.ts:85-99` lit `r.compte` / `r.compte_libelle`
   — champs inexistants. Le cast `as BalanceRow[]` (l.99) masque l'erreur à la compilation.
2. **Complexité actuelle** : type inline dupliqué et désynchronisé du type généré, cast forcé.
3. **Proposition** : lire `r.numero_compte`/`r.libelle` et typer via `Database["public"]["Functions"]["compta_balance"]["Returns"][number]`.
4. **Pourquoi plus simple** : une seule source de vérité de contrat ; toute dérive future casse la compilation.
5. **Périmètre minimal** : `src/lib/compta-api.ts:85-99` uniquement, aucun changement SQL.
6. **Risques** : nuls — la fonctionnalité est déjà cassée (comptes/libellés vides, agrégats à 0).
7. **Validation** : `balance.tsx`, `compta-dashboard.tsx` avec données réelles ; totaux par classe (7/6/5/411/401) non nuls.
8. **Dépendances** : `fec-zip.ts:35`, `balance.tsx:36`, `compta-dashboard.tsx:36`, `exercices.rapport.tsx:123`, `dashboard-global.tsx:116`.
9. **Confiance** : HIGH.

### R2 — Triggers d'audit legacy dupliquant chaque événement CRUD
**Verdict** : CORRIGER · **Sous-système** : Audit S1/S2/S3
**Fichiers** : `supabase/migrations/20260628095421_*.sql:64-70`, `20260704135804_*.sql:129-139`, `src/components/clients/form/ClientForm.tsx:126-146`

1. **Évidence** : les triggers `audit_clients/produits/commandes/factures/paiements/proformas/user_roles` (→ `audit_logs`)
   n'ont jamais été droppés lors de l'introduction de `trg_audit_*` (→ `audit_events`). Sur 4 tables, chaque écriture produit
   2 enregistrements ; `ClientForm.tsx:127-145` ajoute un 3e via l'appel manuel `audit(...)`.
2. **Complexité** : 3 chemins d'écriture, 2 tables d'audit à maintenir/sécuriser.
3. **Proposition** : dropper les 7 triggers legacy + fonction associée, conserver `audit_events`/`audit_row_change()`,
   retirer les appels manuels redondants (sauf métadonnées navigateur à reporter dans le trigger).
4. **Pourquoi plus simple** : une seule source de vérité d'audit.
5. **Périmètre minimal** : 1 migration de suppression + retrait de 2 appels dans `ClientForm.tsx`.
6. **Risques** : écran lisant encore `audit_logs` ; perte du contexte navigateur enrichi si retiré sans report.
7. **Validation** : `rg "audit_logs"` avant suppression ; vérifier `ClientAuditTab.tsx`.
8. **Dépendances** : migration Supabase.
9. **Confiance** : HIGH.

### R3 — Écritures directes mortes contournant les invariants RPC
**Verdict** : SUPPRIMER · **Sous-système** : V3/V4
**Fichiers** : `src/lib/factures-api.ts:199-250`, `src/lib/paiements-api.ts:78-110`

1. **Évidence** : aucun appelant dans `src` (`rg` exhaustif). Ces fonctions écrivent `statut`, `montant_paye`, `montant`
   directement en table, contournant `enregistrer_paiement`/`annuler_paiement`/`valider_commande` et le trigger `trg_paiements_no_delete`.
   `cycle-vente.ts:65-72` documente qu'un chemin d'insertion directe équivalent a déjà causé des doublons côté commandes.
2. **Complexité** : deux chemins de mutation pour le même objet métier, dont un mort.
3. **Proposition** : supprimer les 4 fonctions + types `FactureInput`/`PaiementInput`, ou les faire `throw` comme `deleteFacture:252-255`.
4. **Pourquoi plus simple** : élimine une porte dérobée de désynchronisation `factures.montant_paye` ↔ somme des paiements.
5. **Périmètre minimal** : 2 fichiers, aucun appelant à migrer.
6. **Risques** : quasi nuls (vérifier hors `src` : scripts, edge functions).
7. **Validation** : recherche globale + typecheck.
9. **Confiance** : HIGH.

### R4 — Deux moteurs de paie divergents, dont un mort
**Verdict** : SUPPRIMER · **Sous-système** : S9/S10
**Fichiers** : `src/lib/paie/calculateBulletin.ts:1-95` (+ son test) vs `src/lib/paie/engine.ts:1-208`

1. **Évidence** : `calculateBulletin.ts` fige `PLAFOND_CNPS = 1 647 315`, AT 3 %, abattement 15 %, IR 16/21/24 %,
   alors que `runEngine` applique les paramètres DB (`CNPS_PLAFOND_MENSUEL` 2 700 000, AT 2 %, abattement ITS 20 %, ITS 1,5→20 %).
   Aucun consommateur hors son propre test.
2. **Complexité** : deux jeux de règles fiscales/sociales non synchronisés dans le même dossier.
3. **Proposition** : supprimer les 2 fichiers ; `engine.ts` reste l'unique source de vérité.
4. **Pourquoi plus simple** : supprime un risque de bulletins erronés en cas de réutilisation accidentelle.
6. **Risques** : nuls côté runtime.
7. **Validation** : `rg -l "calculateBulletin"` puis `engine.test.ts`.
9. **Confiance** : HIGH.

### R5 — Faux « backup complet » et deux pipelines d'export concurrents
**Verdict** : CORRIGER · **Sous-système** : S7/S8
**Fichiers** : `src/lib/export-api.ts:95-155`, `src/lib/export-stream.ts:58-143`, `src/routes/_authenticated/exports.tsx:9-99`, `src/lib/global-backup.server.ts`

1. **Évidence** : `export-api.ts` fetch unique plafonné à 10 000 lignes + `triggerDownload` propre (l.104-113) ;
   `export-stream.ts` réimplémente le même besoin avec pagination réelle + `triggerDownload` quasi identique (l.58-67).
   `exportFullBackupJSON` (l.141-155) ne couvre que 8 entités plafonnées, sans users ni storage, mais `exports.tsx:92-93`
   annonce « Sauvegarde complète téléchargée » — en concurrence avec `global-backup.server.ts` (toutes tables + users + storage + SHA-256).
2. **Complexité** : deux moteurs aux garanties différentes (troncature silencieuse) ; deux notions de « sauvegarde complète ».
3. **Proposition** : basculer `exportCSV`/`exportXLSX` sur `streamExport` ; supprimer `exportFullBackupJSON` et rediriger le bouton vers `/backup`
   (ou le renommer « Export brut limité — 8 tables, 10k lignes »).
4. **Pourquoi plus simple** : un moteur d'export, une notion de sauvegarde, fin de la perte de données silencieuse.
6. **Risques** : changement de nom de fichier généré ; usage métier éventuel du JSON léger.
7. **Validation** : confirmer l'usage réel du JSON avant suppression ; tester CSV/XLSX sur les 8 entités.
9. **Confiance** : HIGH.

### R6 — Centraliser l'écriture de `stocks_depots`/`stock_mouvements`
**Verdict** : CENTRALISER · **Sous-système** : S3/S4/S6
**Fichiers** : `20260806110000_fix_stock_adjustment.sql:29-72` (fonction centrale) ; réimplémentations :
`20260717100149_*.sql:163-291` (`regulariser_inventaire`, `executer_transfert`, `receptionner_transfert`),
`20260718152145_*.sql:115-125` (`creer_retour`), `20260718125436_*.sql:56-63` (`creer_incident_stock`),
`20260717101908_*.sql:231-235` (`annuler_colisage`).

1. **Évidence** : 6 implémentations du pattern « lock → delta → UPDATE `stocks_depots` → INSERT `stock_mouvements` ».
   Seule `ajuster_stock_depot` contrôle la portée dépôt utilisateur (`user_depots`, l.46-50) ; les 5 autres non.
3. **Proposition** : faire appeler `ajuster_stock_depot(..., _origine, _document_id)` par ces fonctions.
4. **Pourquoi plus simple** : un point de vérité pour la portée dépôt, le delta et la structure du mouvement ; `audit_stock_anomalies` conçu pour une source unique.
6. **Risques** : `ajuster_stock_depot` prend une **quantité absolue**, les appelants raisonnent en **delta** ;
   le type de mouvement inféré (`entree`/`sortie`) diffère des libellés en dur (`transfert_sortant`/`transfert_entrant`) potentiellement filtrés en UI.
7. **Validation** : test bout-en-bout par flux + `audit_stock_anomalies()` à 0 ; vérifier les filtres de `stock_.$produitId.mouvements.tsx`.
9. **Confiance** : MEDIUM.

### R7 — Invalidation de cache RH incomplète et divergente
**Verdict** : CORRIGER · **Sous-système** : S5/S11/S12
**Fichiers** : `src/lib/cache-invalidation.ts`, `src/components/rh/EmployeForm.tsx:160-166`, `src/routes/_authenticated/employes.index.tsx:86,110,122`, `conges.index.tsx:61,70`, `CongeForm.tsx:55`

1. **Évidence** : `cache-invalidation.ts` couvre Ventes/Stock/Compta mais aucun helper RH. `EmployeForm` invalide 7 clés
   (`employes, employe, rh-dashboard, paie, bulletins, absences, conges`) ; `employes.index.tsx` n'en invalide qu'une
   sur suppression/restauration/renumérotation — opérations qui impactent pourtant les mêmes domaines.
3. **Proposition** : ajouter `invalidateEmploye(qc, id?)` et `invalidateConge(qc, …)` et remplacer les appels dispersés.
4. **Pourquoi plus simple** : une liste de clés par domaine, alignée sur le pattern existant.
6. **Risques** : faibles, comportement additif.
7. **Validation** : parcours suppression/restauration employé + création congé ; `rg -n "invalidateQueries" src/routes/_authenticated/employes* src/components/rh`.
9. **Confiance** : MEDIUM.

### R8 — Fusionner la façade `fabsTemplates.ts` avec `unified-generator.ts`
**Verdict** : FUSIONNER · **Sous-système** : DOC-01/DOC-02
**Fichiers** : `src/lib/pdf/fabsTemplates.ts:191-229`, `src/lib/pdf/unified-generator.ts:1-222`

1. **Évidence** : 9 fonctions publiques ne font que déléguer à 5 fonctions `generateUnified*` avec un libellé de type ;
   `unified-generator.ts:6` réimporte les types `DocBase`/`DocLigne` depuis la façade → **dépendance circulaire de types**.
3. **Proposition** : fusionner les deux fichiers, conserver les exports publics identiques (26 appelants inchangés).
4. **Pourquoi plus simple** : un saut d'indirection en moins, fin du cycle d'imports.
6. **Risques** : faibles ; surveiller l'ordre d'initialisation de `ensurePdfLogo`.
7. **Validation** : générer un PDF de chaque type et comparer visuellement.
9. **Confiance** : HIGH.

### Anomalie signalée (bug, pas simplification) — PDF Incidents vide
`src/lib/pdf/fabsTemplates.ts:233-241` : `generateIncidentPDF` et `generateRapportIncidentsPDF` renvoient
`new Blob([], …)` après un `console.warn`, alors que l'UI (`incidents.$incidentId.tsx:82,144`, `incidents.index.tsx:159`
via `incidents-pdf.ts:20-92,134`) exécute un enrichissement complet en amont. À traiter comme ticket bug d'implémentation.

---

## 4. SKIP motivés

| Sujet | Motif |
|---|---|
| Doublon d'expansion `.voir` (`rbac3-bridge.ts:132-136` vs `rbac-permission-normalize.ts:8-25`) | Entrées différentes (v3 brut vs v2 déjà étendu), 25 lignes, usage diagnostic ; risque d'hypothèse > gain |
| Coexistence `has_permission_v2` / `rbac3_can` | Pont de migration assumé et documenté ; 97 occurrences en migrations + policies RLS métier — migration de sécurité, pas une simplification |
| Recalcul de totaux `CommandeForm.tsx:181-195` | Preview UX ; le payload n'envoie aucun total, la RPC fait autorité |
| Colisage / étiquetage | Chemin unique `creer_colisage_manuel` + `buildEtiquettesPrintHtml` ; aucune duplication trouvée |
| États tournées / livraison-suivi | `LivStatut` union stricte pilotée par RPC ; `cloture_*` = métadonnées, pas un second état |
| jsPDF vs pdf-lib | Coexistence intentionnelle documentée (`pdfGenerator.ts:28-36`), chrome partagé |
| `ecritureEquilibree` vs `guard_ecriture_balance` | Helper TS utilisé uniquement en test ; autorité exclusive en base |
| Valorisation stock (CMUP/PMP) | Inexistante ; seule duplication triviale intra-fichier dans `rapports-index-defs.ts` (hors périmètre) |
| Empilement de migrations RH | Preuve de redondance non établie en lecture seule |

---

## 5. Priorisation

- **P0 — corriger immédiatement** : R1 (comptabilité faussée : balance, FEC, dashboard).
- **P1 — court terme** : R2 (intégrité/volume d'audit), R3 (surface d'écriture dangereuse), R4 (risque paie),
  R5 (fausse promesse de sauvegarde), bug PDF Incidents.
- **P2 — moyen terme** : R6 (centralisation stock, nécessite tests par flux), R7 (cache RH).
- **P3 — opportuniste** : R8 (fusion façade PDF).

---

*Audit produit en lecture seule. Aucune correction, refactorisation, migration ou suppression n'a été effectuée.*

---

## 6. Suivi d'application (lot P1)

| Reco | État | Détail |
|---|---|---|
| R1 | ✅ Appliqué | Mapping `compta_balance` corrigé via le type généré. |
| R2 | ✅ Appliqué | Une seule source d'audit : le trigger DB `audit_crud_clients`. Les 2 appels manuels `audit()` de `ClientForm.tsx` (3e écriture) ont été retirés. Vérifié en base : `audit_events` est une **vue** sur `audit_logs`, un seul système de triggers subsiste (`audit_crud_*`). |
| R3 | ✅ Appliqué | Écritures directes mortes ventes/paiements supprimées. |
| R4 | ✅ Appliqué | Moteur de paie orphelin `calculateBulletin.ts` supprimé. |
| R5 | ✅ Appliqué | `exportFullBackupJSON` supprimé ; `/exports` renvoie désormais vers le module `/backup` (source unique de sauvegarde), et annonce explicitement la limite de 10 000 lignes des exports par module. |
| Bug PDF Incidents | ✅ Corrigé | `IncidentDocument` / `RapportIncidentsDocument` (`src/lib/pdf/incident-document.ts`) branchés sur le moteur pdf-lib unifié ; PDF générés vérifiés (~30 Ko, non vides). |

Restent ouverts : R6 (centralisation stock, P2), R7 (invalidation cache RH, P2), R8 (fusion façade PDF, P3).
