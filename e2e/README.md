# Tests E2E Playwright

## Prérequis

1. Installer les navigateurs Playwright (une seule fois) :
   ```bash
   bun run test:e2e:install
   ```
2. Créer un utilisateur de test avec le rôle `super_admin` en base
   (nécessaire pour créer/supprimer les fixtures via l'API PostgREST
   soumise à la RLS).
3. Exporter ses identifiants avant le run :
   ```bash
   export E2E_TEST_EMAIL="qa+livsuivi@example.com"
   export E2E_TEST_PASSWORD="********"
   # Optionnel : cibler un autre environnement
   # export E2E_BASE_URL="https://fabsci-gest.lovable.app"
   ```

## Lancer

```bash
bun run test:e2e
```

Playwright démarre `bun run dev` automatiquement si `E2E_BASE_URL` n'est
pas défini, puis exécute les specs de `e2e/*.spec.ts`.

## Fixtures

Chaque test crée son propre couple `client + commande + colis + livsuivi_commandes`
et le supprime dans `afterAll` — aucune donnée n'est laissée en base.