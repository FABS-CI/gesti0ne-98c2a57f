## Audit préalable (fait)

Éléments existants repérés :

- **PDF** : tout passe par `src/lib/pdf/fabsTemplates.ts` (template unique `buildTableDoc` + `drawHeader`). Le bon de réception est le type `BA` (titre actuel « Bon de Réception (Approvisionnement) »), le reçu de paiement `RP` (signature « Le Caissier », double titre « REÇU DE PAIEMENT »). Le relevé de compte est généré depuis `src/routes/_authenticated/etat-compte-clients.tsx`.
- **Approvisionnement** : `src/lib/achats-api.ts` (RPC `enregistrer_approvisionnement` / `modifier_approvisionnement`), écrans `achats.index.tsx`, `achats.nouveau.tsx`, composants `src/components/achats/nouveau/`.
- **Fournisseurs** : `src/lib/fournisseurs-api.ts`, table `fournisseurs` (10 colonnes) — **aucune colonne référence** aujourd'hui. Formulaire actuellement en modale sur `fournisseurs.index.tsx`.
- **Auto-save** : `src/hooks/use-autosave.ts` existe déjà mais en **localStorage uniquement** (pas de brouillon serveur, pas d'anti-doublon multi-poste).
- **Temps réel** : `src/hooks/use-realtime-bus.ts` (Supabase Realtime) déjà en place — à étendre aux retours/avoirs.
- **Lignes d'achat** : `achat_lignes` n'a pas de colonne remise.

---

## Lot 1 — Intégrité des données (§5 + §4)

1. Migration : table `document_drafts` (user_id, doc_type, draft_id, entity_id, payload jsonb, status draft/converted) + contrainte unique (user_id, doc_type, draft_id) + RLS propriétaire.
2. Migration : colonne `idempotency_key` (nullable, UNIQUE partiel) sur `achats`, `commandes`, `paiements` ; contrôle dans les RPC d'enregistrement → renvoi du document existant au lieu d'un doublon.
3. Hook `useServerDraft` (upsert debounce 10 s) + bandeau « Un brouillon non terminé a été trouvé — reprendre / recommencer ».
4. Frontend : `isSubmitting` + spinner systématique sur les boutons de validation (achat, commande, paiement, réception).

## Lot 2 — Référence fournisseur + Bon de réception (§2 + §1)

1. Migration : colonne `reference` sur `fournisseurs`, séquence `FRS-0001`, backfill des 
existants, contrainte UNIQUE, trigger de génération.
2. Colonne `remise_pct` (numeric default 0) sur `achat_lignes` ; recalcul `total_ligne = pu × qté × (1 − remise/100)` dans les RPC d'approvisionnement (impact coût d'entrée en stock).
3. UI ligne d'achat : colonne « Remise (%) » saisissable 0–100.
4. Renommage global « Bon de réception d'approvisionnement » → « Bon de réception ».
5. PDF `BA` : bloc fournisseur complet (raison sociale, référence, adresse, tel, email, contact), colonne Remise, signature « Responsable de la gestion des stocks ».

## Lot 3 — Formulaires en page complète (§3)

Routes dédiées `fournisseurs/nouveau`, `fournisseurs/$id/modifier`, bon de réception ; suppression des modales de création, bouton Retour + breadcrumb, responsive.

## Lot 4 — Finitions PDF (§10, §11, §12)

- BA : marges, alignements, tailles de police, pagination testée 1 et 30+ lignes.
- Relevé de compte : charte orange, suppression colonne « Libellé », colonnes Date / Type / Référence / Facture / Débit / Crédit / Solde, encadré récap (factures, paiements, avoirs, retours, solde, date d'édition).
- Reçu de paiement : suppression du titre redondant, bande orange, signatures « Client | Comptabilité ».

## Lot 5 — Filtres approvisionnement (§8)

Filtres combinables Article (recherche partielle), Référence article, Catégorie — en plus du fournisseur, côté requête SQL.

## Lot 6 — Proforma (§6) + Temps réel (§7)

- Proforma : reprise des infos de la commande liée + badges « Champ manquant » sur adresse de livraison, contact, conditions de paiement.
- Realtime : abonnement retours/avoirs propagé aux dashboards stock & compta, liste commandes, relevé client + toast discret.

## Lot 7 — Runbook & test de restauration (§14)

Rédaction du runbook pas-à-pas (hors ERP), test de restauration réel documenté, planification trimestrielle.

---

## Détails techniques

- Toutes les migrations sont additives (colonnes nullables + défaut), aucune suppression de données historiques.
- L'idempotence est vérifiée côté serveur dans les RPC existantes, sans changer leur signature publique (paramètre optionnel).
- Le PDF reste sur `pdf-lib` via `fabsTemplates.ts` — pas de nouvelle dépendance.

Rapport récapitulatif (fichiers, migrations, tests, points à valider) fourni à la fin de chaque lot.
