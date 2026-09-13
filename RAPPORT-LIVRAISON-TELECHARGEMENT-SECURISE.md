# Rapport de livraison — Vérification et téléchargement sécurisé des documents GESTI-ONE

Périmètre : Prompts 0 à 10 du cahier des charges "vérification et téléchargement sécurisé". Ce rapport couvre l'audit initial, les changements livrés, et ce qui reste à valider en conditions réelles (aucun accès à votre base Supabase ni à un environnement exécutable n'était disponible pendant ce travail).

## 1. Constat de départ (Prompt 0 & 1)

Déjà en place et jugé solide, non modifié :
- Séparation stricte référence métier / jeton de vérification (`verifyByReference` vs `verifyByToken` dans `certification.server.ts`).
- Jeton 256 bits (`randomBytes(32)`), stocké uniquement en `token_hash` SHA-256 — jamais en clair.
- Signature Ed25519 par document, recalcul d'empreinte SHA-256, détection `TAMPERED`.
- Rate limiting de la vérification (30/10 min par IP hashée), journal d'audit (`document_verification_logs`), `Cache-Control: no-store`.

Manquant et livré dans ce travail :
- Aucun bouton de téléchargement n'existait sur la page `/verify/$uuid`.
- Aucune route de téléchargement sécurisée n'existait.
- La génération PDF officielle (`base-document.ts` / `fabsTemplates.ts`) était exclusivement côté navigateur (`fetch` sur URL relative, `Image`, `FileReader`) — inutilisable telle quelle dans une route serveur.

Point non résolu, à traiter séparément : les tables `document_certifications`, `signature_keys`, `document_verification_logs` existent en base mais **aucune migration correspondante n'est présente dans `supabase/migrations/`**. Cela pose un risque pour votre procédure de rollback (Prompt 9) — je recommande de générer une migration de rattrapage (`supabase db diff`) avant toute mise en production de ce lot.

## 2. Fichiers livrés

| Fichier | Nature | Rôle |
|---|---|---|
| `src/routes/api/secure-documents.$token.download.ts` | Créé | Route de téléchargement sécurisée (Prompt 4) |
| `src/lib/certification/certification.server.ts` | Modifié | + `verifyTokenForDownload`, `loadFullDocumentForDownload`, `isDownloadRateLimited` |
| `src/lib/pdf/enrich-lignes.server.ts` | Créé | Chargeurs de données (lignes, client, totaux) via `supabaseAdmin`, pour contexte public sans session |
| `src/lib/pdf/base-document.ts` | Modifié | Logo PDF résolu en URL absolue quand exécuté côté serveur (seul point bloquant la génération serveur) |
| `src/routes/verify.$uuid.tsx` | Modifié | Bouton de téléchargement, adapté au type réel, visible uniquement si `AUTHENTIC` + jeton présent |
| `e2e/secure-documents-download.spec.ts` | Créé | Matrice de tests API (Prompt 8), voir §5 |

Aucun fichier existant supprimé. Aucune donnée, référence, QR code ou document existant modifié.

## 3. Fonctionnement du jeton (rappel, non modifié)

- Généré côté serveur (256 bits aléatoires), distinct de la référence métier.
- Stocké haché (SHA-256) en base, jamais en clair.
- Associé à une certification (`document_certifications`) : type, id interne, statut, empreinte, signature.
- Pas de colonne d'expiration temporelle native aujourd'hui (`expires_at` absente) — la révocation se fait via changement de `statut` (`REVOKED`/`CANCELLED`). Si une expiration temporelle est requise, c'est une migration de schéma à prévoir séparément.

## 4. Route de téléchargement — comportement exact

`GET /api/secure-documents/{token}/download`

1. Rejette tout jeton mal formé (400) avant toute recherche en base.
2. Applique un rate limiting dédié (10/min par IP et par jeton), 429 générique si dépassé, journalisé.
3. Revalidation complète et non mise en cache : `verifyTokenForDownload` refait hash, signature, empreinte, statut de révocation, dans le même style que `verifyByToken`.
4. Si le statut n'est pas `AUTHENTIC` : refus générique (403), journalisé avec le motif réel côté serveur uniquement.
5. Si authentique : chargement des données complètes (lignes, client, totaux) via `supabaseAdmin` (jamais via le client anon/RLS) et génération du PDF officiel correspondant au **type réel** (`FACTURE`/`PROFORMA`/`COMMANDE`/`BL`), en mémoire (`Blob` → `ArrayBuffer`), sans fichier temporaire.
6. Réponse : `Content-Type: application/pdf`, `Content-Disposition: attachment; filename="..."` (nom généré côté serveur), `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`.
7. Toute erreur interne renvoie une réponse générique (503) sans détail technique, journalisée côté serveur avec la trace complète (`console.error`).

Décision produit validée avec vous : le PDF téléchargeable contient le **détail complet des lignes** (comme le PDF interne), et non un résumé — accessible uniquement via jeton valide, jamais via la seule référence.

## 5. Matrice de tests (Prompt 8)

Automatisés dans `e2e/secure-documents-download.spec.ts` (exécutables sans fixture métier) :
- Jeton mal formé → 400, aucun PDF.
- Jeton bien formé mais inconnu → refusé, aucun PDF.
- Tentative d'injection dans le paramètre de route → 400.
- Réponse d'échec sans donnée confidentielle (nom client, montant, id interne, trace technique).
- En-têtes anti-cache présents même en échec.
- Changement de méthode HTTP (POST) → rejeté.
- Téléchargements rapides répétés → 429 déclenché.
- Absence d'écart de timing exploitable entre "mal formé" et "inexistant".

Gated (nécessitent `E2E_TEST_VERIFIED_TOKEN`, un jeton réel d'un document `AUTHENTIC` en environnement de test) :
- Téléchargement réussi : PDF valide (`%PDF`), en-têtes corrects.
- Cohérence sur réutilisation du même jeton.

**Non automatisable sans un deuxième compte/organisation de test** (à faire manuellement ou en ajoutant une fixture dédiée) : accès horizontal entre deux clients, accès vertical entre rôles, comportement pour un utilisateur non connecté sur un document à publication restreinte — ces cas dépendent de règles de droits d'accès par document qui n'existent pas encore dans le schéma actuel (voir §1, aucune colonne de "règles de publication").

## 6. Limites restantes et recommandations

- **Migrations manquantes** : rapatrier `document_certifications`, `signature_keys`, `document_verification_logs` dans `supabase/migrations/` (voir §1).
- **Pas d'expiration de jeton** : uniquement révocation par statut. À évaluer selon votre politique de sécurité.
- **Pas de règles de publication par document** : tout jeton `AUTHENTIC` donne accès au PDF complet, y compris les lignes. Cohérent avec la décision produit prise, mais à documenter explicitement pour vos utilisateurs (le jeton doit être traité comme un secret, pas comme la référence).
- **Build non exécuté** : je n'avais pas accès à `node_modules` ni à votre Supabase pour lancer `npm run build`, `tsc --noEmit` ou la suite e2e complète. À faire impérativement avant fusion.
- **Rétention des journaux** : aucune politique de purge automatique n'a été ajoutée à `document_verification_logs` (nécessite une tâche planifiée / fonction Supabase dédiée) — hors périmètre de ce lot, à traiter si souhaité.

## 7. Variables d'environnement nécessaires (sans valeurs)

Aucune nouvelle variable requise. Utilise les variables déjà en place : `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `DOC_SIGNING_PRIVATE_KEY`, `DOC_SIGNING_PUBLIC_KEY`.

## 8. Déploiement et retour arrière

- Déploiement : appliquer le patch fourni, exécuter le build et les tests, déployer normalement (aucune migration de base nécessaire pour ce lot).
- Retour arrière : `git revert` des 5 fichiers listés en §2 restaure exactement le comportement précédent (page de vérification sans bouton de téléchargement, pas de route de téléchargement). Aucune donnée n'étant modifiée par ce lot, le rollback est sans risque pour les données existantes.

Aucun secret, mot de passe ou jeton n'est présent dans ce rapport.
