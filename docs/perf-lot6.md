# Lot 6 — Export CSV / Excel streaming pour grandes listes

## Objectif

Permettre l'export de **très grandes listes** (10k+ lignes : audit, ventes annuelles, écritures comptables, historiques colis) sans figer le navigateur ni saturer la mémoire.

## Livrables

- `src/lib/export-stream.ts` :
  - `streamExport({ format: 'csv' | 'xlsx', columns, fetchPage, pageSize, onProgress })`.
  - CSV : UTF-8 avec BOM, séparateur `;` (Excel FR), échappement RFC 4180.
  - XLSX : SheetJS chargé en dynamic import (bundle allégé pour les écrans qui n'exportent pas).
  - Callback `onProgress({ fetched, total })` pour brancher un toast/toolbar.
  - Nom de fichier automatiquement horodaté `slug-YYYYMMDD-HHMM.ext`.

## Utilisation type (liste paginée Supabase)

```ts
import { streamExport } from '@/lib/export-stream';
import { supabase } from '@/integrations/supabase/client';

await streamExport({
  filename: 'ventes',
  format: 'xlsx',
  columns: [
    { key: 'numero', label: 'N° Facture' },
    { key: 'client', label: 'Client', accessor: (r) => r.clients?.nom },
    { key: 'total_ttc', label: 'Total TTC (FCFA)' },
    { key: 'date_facture', label: 'Date' },
  ],
  pageSize: 1000,
  fetchPage: async (page, size) => {
    const from = page * size;
    const { data } = await supabase
      .from('factures')
      .select('numero,total_ttc,date_facture,clients(nom)')
      .order('date_facture', { ascending: false })
      .range(from, from + size - 1);
    return data ?? [];
  },
  onProgress: ({ fetched, total }) =>
    toast.loading(`Export en cours… ${fetched}${total ? ` / ${total}` : ''}`, { id: 'exp' }),
});
```

## Règles

- **Toujours** utiliser `streamExport` pour des listes potentiellement supérieures à 5 000 lignes.
- Pour < 500 lignes ou pour un rendu formaté imprimable, garder `exportPdf` (`src/lib/export-csv.ts`).
- Ne pas faire un `select()` sans `range()` côté `fetchPage` (limite PostgREST 1000).
- Colonnes dérivées : utiliser `accessor` plutôt que dénormaliser dans le `select`.

## Cibles prioritaires (à câbler ensuite)

1. Journal des ventes / factures annuelles
2. Écritures comptables (FEC)
3. Audit logs (`audit_logs`)
4. Historique colis / suivis de livraison
5. Historique paiements client
