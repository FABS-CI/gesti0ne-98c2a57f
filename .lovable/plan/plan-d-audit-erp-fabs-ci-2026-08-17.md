# Plan d'Audit ERP FABS-CI

## Objectifs
- Valider la fiabilité des données opérationnelles (Ventes, Stocks, Finance).
- Identifier les modules fonctionnels vs les placeholders.
- Auditer la sécurité RBAC et les impacts comptables.
- Fournir un rapport de conformité pour la migration depuis Express Invoice.

## Méthodologie
1. **Extraction Technique** : Analyse des schémas SQL, des RLS et des fonctions RPC.
2. **Audit Fonctionnel** : Test des flux critiques (Commande -> Stock -> Facture -> Compta).
3. **Audit de Sécurité** : Vérification du moteur RBAC v3 et suppression de la dette v1/v2.
4. **Validation PDF** : Vérification de la conformité des documents FABS (Bleu #1B2A57, Orange #FFF3E0).

## Livrables
- Rapport final avec score de fiabilité.
- Liste des correctifs P0 (Priorité 0).
- Recommandation "GO/NO-GO" pour la production.
