# PERFORMANCE BACKLOG — GESTI-ONE 2.0.2

Ce document répertorie les optimisations identifiées lors de l'audit 2.0.1-AUDIT, à implémenter uniquement après observation des données réelles de production.

## Baseline Production (2.0.1-AUDIT)
- **Dashboard :** ≈ 3,96 secondes
- **Tests :** 110 / 110 PASS
- **Statut :** VERSION GELÉE 🟢

## Backlog d'Optimisation 2.0.2

### 1. Dashboard (> 3 secondes)
- **Problème :** Latence perçue lors du chargement initial.
- **Cause probable :** Agrégations SQL complexes sur les ventes et stocks.
- **Risque :** Moyen (Intégrité des données).

### 2. Requêtes SQL N+1
- **Problème :** Multiples appels lors du rendu des listes de produits/clients.
- **Correction :** Utilisation de `JOIN` ou de vues matérialisées.

### 3. Bundle & Re-render
- **Problème :** Taille du bundle JS impactant le FCP.
- **Correction :** Lazy loading des composants PDF et graphiques Recharts.

### 4. Indexation & Cache
- **Problème :** Temps de réponse DB sur les gros volumes.
- **Correction :** Ajout d'index sur `date_commande` et `statut`.

---
*Note : Toute modification dans ce backlog doit être justifiée par une mesure P95/P99 en production.*
