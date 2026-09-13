# Certification automatique — Factures, Bons de commande, Proformas

## Plan en 5 lignes

1. **Base de données** : aucune nouvelle table — on réutilise `document_certifications`, `signature_keys`, `document_verification_logs` ; on ajoute un index unique sur (type, document_id, version) si absent et on garde tout l'existant.
2. **Serveur** : nouvelle fonction `ensureCertification(reference)` (idempotente) dans `certification.server.ts` + serveur-fonction publique authentifiée `ensureCertificationFn`, qui certifie automatiquement FACTURE / COMMANDE / PROFORMA et renvoie empreinte, version, date et lien de vérification ; les BL restent hors périmètre.
3. **Déclenchement automatique** : appel de `ensureCertification` lors de la validation/génération des documents (`cycle-vente.ts` : facture, commande, proforma) et, en filet de sécurité, juste avant la génération du PDF.
4. **PDF / QR** : `base-document.ts` + `docTypeConfig.ts` récupèrent la certification avant rendu et impriment le bloc « Certification numérique » (statut, version, date, empreinte, QR bleu vers `/verify/<référence>`) sur FAC, BC et PROFORMA uniquement.
5. **UI et page publique** : suppression du bouton « Certifier ce document » dans `CertificationCard.tsx` (affichage seul, révocation conservée pour l'administrateur) ; `verify.$uuid.tsx` et `api/public/verify-doc.$uuid.ts` affichent « DOCUMENT AUTHENTIQUE » ou « DOCUMENT NON AUTHENTIQUE », vérification 100 % serveur.

## Points techniques

- Empreinte SHA-256 sur la représentation canonique existante, signature Ed25519 côté serveur ; le frontend ne décide jamais de l'authenticité.
- Idempotence : si une certification AUTHENTIC existe déjà avec la même empreinte, on la réutilise ; si le document a changé, une nouvelle version est créée.
- Aucun document existant hors FAC / BC / PROFORMA n'est modifié, aucune donnée supprimée, la génération PDF actuelle reste fonctionnelle.
