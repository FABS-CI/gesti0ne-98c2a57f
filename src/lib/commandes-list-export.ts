import { STATUT_LABEL, type Commande } from "@/lib/commandes-api";
import { exportCsv } from "@/lib/export-csv";
import { exportListePDF } from "@/lib/pdf/exportListe";
import { describeFilters, type AdvancedFilters } from "@/components/search/AdvancedSearchBar";

export function exportCommandesCsv(items: Commande[]) {
  const totalMt = items.reduce((s, c) => s + (Number(c.montant_total) || 0), 0);
  const statutCount = items.reduce<Record<string, number>>((acc, c) => {
    acc[c.statut] = (acc[c.statut] ?? 0) + 1;
    return acc;
  }, {});
  exportCsv(
    "commandes",
    ["Reference", "Client", "Statut", "Date", "Total"],
    items.map((c) => [
      c.reference,
      c.client_nom ?? "",
      STATUT_LABEL[c.statut]?.label ?? c.statut,
      c.date_commande,
      c.montant_total,
    ]),
    {
      pageTitle: "LISTE DES COMMANDES",
      summary: [
        { label: "Nombre de commandes", value: String(items.length) },
        {
          label: "Clients distincts",
          value: String(new Set(items.map((c) => c.client_nom).filter(Boolean)).size),
        },
        { label: "Montant total", value: __FMT__(totalMt) },
        ...Object.entries(statutCount).map(([k, v]) => ({
          label: STATUT_LABEL[k]?.label ?? k,
          value: String(v),
        })),
      ],
    },
  );
}

export function exportCommandesPdf(
  items: Commande[],
  q: string,
  statut: string,
  advanced: AdvancedFilters,
) {
  const filtres: string[] = [];
  if (q) filtres.push(`Recherche : ${q}`);
  if (statut && statut !== "all") filtres.push(`Statut : ${STATUT_LABEL[statut]?.label ?? statut}`);
  filtres.push(...describeFilters(advanced));
  exportListePDF({
    titre: "Liste des commandes",
    colonnes: ["Référence", "Date", "Client", "Ville", "Statut", "Total (FCFA)"],
    lignes: items.map((c) => [
      c.reference,
      c.date_commande,
      c.client_nom ?? "",
      c.ville ?? "",
      STATUT_LABEL[c.statut]?.label ?? c.statut,
      __FMTN__(Number(c.montant_total)),
    ]),
    filtres,
    filename: "commandes",
  });
}
