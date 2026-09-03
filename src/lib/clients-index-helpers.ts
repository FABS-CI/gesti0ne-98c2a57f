import { listClients } from "@/lib/clients-api";
import { TYPE_COLOR } from "@/lib/company";
import { exportCsv } from "@/lib/export-csv";
import type { CrmFilters } from "@/lib/crm-api";

export const PAGE_SIZE = 50;

export function isCrmActive(f: CrmFilters): boolean {
  return !!(
    f.produits?.length ||
    f.niveaux?.length ||
    f.categories?.length ||
    f.types?.length ||
    f.villes?.length ||
    f.representant ||
    f.from ||
    f.to
  );
}

export async function exportClientsPdf(filters: {
  q?: string;
  type_client?: string;
  actif?: boolean;
}) {
  const all = await listClients({ ...filters, page: 1, pageSize: 10000 });
  const headers = ["Référence", "Nom", "Type", "Représentant", "Téléphone", "Solde"];
  const rows = all.items.map((c) => [
    c.reference,
    c.nom,
    TYPE_COLOR[c.type_client]?.label ?? c.type_client,
    c.representant ?? "",
    c.telephone ?? "",
    c.solde,
  ]);
  const totalSolde = all.items.reduce((s, c) => s + (Number(c.solde) || 0), 0);
  const debiteurs = all.items.filter((c) => Number(c.solde) > 0).length;
  const crediteurs = all.items.filter((c) => Number(c.solde) < 0).length;
  const actifs = all.items.filter((c) => c.actif).length;
  exportCsv(`clients_fabs_${new Date().toISOString().slice(0, 10)}`, headers, rows, {
    pageTitle: "LISTE DES CLIENTS",
    summary: [
      { label: "Nombre total de clients", value: String(all.items.length) },
      { label: "Clients actifs", value: String(actifs) },
      { label: "Clients débiteurs", value: String(debiteurs) },
      { label: "Clients créditeurs", value: String(crediteurs) },
      { label: "Encours total", value: formatFCFA(totalSolde) },
    ],
  });
  return all.items.length;
}
