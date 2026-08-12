# Plan — Optimisation de la Recherche Globale (v2.0.3)

Améliorer la recherche globale pour inclure les numéros de téléphone normalisés et optimiser les performances via l'indexation.

## Changements

### Backend (Base de données)
- **Normalisation** : Créer une migration pour s'assurer que `profiles` et `employes` ont également des colonnes `phone_normalized`.
- **Indexation** : Ajouter des index GIN trigram (`pg_trgm`) sur `nom`, `raison_sociale`, `reference` et les colonnes `phone_normalized` pour permettre des recherches partielles rapides.
- **RPC de recherche** : Créer une RPC `public.global_search(query text)` centralisée qui effectue une recherche optimisée sur toutes les tables pertinentes (Clients, Employés, Documents).

### Frontend (Application)
- **GlobalSearch.tsx** : Remplacer les appels `supabase.from(...).or(...)` multiples par un appel unique à la nouvelle RPC `global_search`.
- **Normalisation Client** : Appliquer `normalize_phone` côté client avant l'envoi pour assurer la cohérence si nécessaire, bien que la RPC s'en chargera.

## Détails techniques

### Schéma SQL
- `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_normalized text;`
- `ALTER TABLE public.employes ADD COLUMN IF NOT EXISTS phone_normalized text;`
- Triggers de normalisation pour `profiles` et `employes`.
- Index : `CREATE INDEX idx_clients_phone_norm_trgm ON public.clients USING gin (phone_normalized gin_trgm_ops);`

### Recherche
- Utilisation de `pg_trgm` pour gérer les recherches comme "1234" trouvant "0505123456".
- La RPC retournera un format unifié compatible avec le type `Hit` du frontend.

## Évaluation de la sécurité
- Utilisation de `SECURITY DEFINER` et `search_path = public` pour les RPC.
- Vérification des permissions via `public.assert_permission` à l'intérieur de la RPC.
- Requêtes paramétrées pour prévenir les injections SQL.
