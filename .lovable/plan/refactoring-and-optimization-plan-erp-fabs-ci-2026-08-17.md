# Refactoring and Optimization Plan - ERP FABS-CI

This plan targets technical debt, data integrity, and performance bottlenecks identified during the v2.2.1 audit.

## User Impact
- **Accuracy**: Stock levels will be real-time and accurate across all screens.
- **Reliability**: Faster dashboard loading and zero financial discrepancies in BI.
- **Security**: cleaner permission management and robust session handling.

## Technical Details

### Step 1: Real-time Stock Aggregation (Data Layer)
- **Goal**: Replace legacy `produits.stock` (static 1000) with dynamic sums from `stocks_depots`.
- **Action**: Modify `src/lib/produits-api.ts` to join `stocks_depots` and compute sums.
- **Action**: Update `useDashboardOverview` to use aggregated counts for "Stock Bas".

### Step 2: Financial BI Correction
- **Goal**: Restore "Valeur du stock" and "Top produits" in BI Analytics using real data.
- **Action**: Update `src/routes/_authenticated/bi-analytics.tsx` to calculate valuation based on `stocks_depots * prix_vente`.

### Step 3: RBAC v3 Migration & Cleanup
- **Goal**: Decommission legacy permission checks and unify on the v3 bridge.
- **Action**: Audit all `Can` components and `hasPerm` calls to ensure they use the `rbac3-bridge.ts`.

### Step 4: PDF Engine Performance
- **Goal**: Optimize large document generation (Account Statements, Order Lists).
- **Action**: Implement stream-like chunking or worker-based generation for documents > 50 pages.

### Step 5: Frontend "Any" Debt Removal
- **Goal**: Finalize Type-safety in complex forms (`CommandeForm`, `RetourForm`).
- **Action**: Replace remaining `any` casts with strict Zod-validated types.

## Verification
- Run `npm run build` to check for type regressions.
- Verify dashboard "Stock Bas" count matches the sum of warehouse alerts.
- Check BI Analytics "Valeur du stock" is non-zero and reflects reality.
