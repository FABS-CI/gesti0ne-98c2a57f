import { supabase } from "@/integrations/supabase/client";

export type ExportEntity = {
  key: string;
  label: string;
  table:
    | "clients"
    | "produits"
    | "factures"
    | "paiements"
    | "bons_livraison"
    | "commandes"
    | "fournisseurs"
    | "employes";
  columns: string[];
  orderBy?: string;
};

export const EXPORT_ENTITIES: ExportEntity[] = [
  {
    key: "clients",
    label: "Clients",
    table: "clients",
    columns: ["client_id", "nom", "email", "telephone", "ville", "representant", "created_at"],
    orderBy: "nom",
  },
  {
    key: "produits",
    label: "Produits",
    table: "produits",
    columns: ["produit_id", "titre", "reference", "isbn", "prix_vente", "stock", "created_at"],
    orderBy: "titre",
  },
  {
    key: "factures",
    label: "Factures",
    table: "factures",
    columns: [
      "facture_id",
      "reference",
      "client_nom",
      "date_facture",
      "date_echeance",
      "montant_total",
      "montant_paye",
      "statut",
    ],
    orderBy: "date_facture",
  },
  {
    key: "paiements",
    label: "Paiements",
    table: "paiements",
    columns: [
      "paiement_id",
      "reference",
      "client_nom",
      "date_paiement",
      "montant",
      "mode_paiement",
      "statut",
    ],
    orderBy: "date_paiement",
  },
  {
    key: "bons_livraison",
    label: "Bons de livraison",
    table: "bons_livraison",
    columns: ["bl_id", "reference", "client_nom", "date_livraison", "statut", "transporteur"],
    orderBy: "date_livraison",
  },
  {
    key: "commandes",
    label: "Commandes",
    table: "commandes",
    columns: ["commande_id", "reference", "client_nom", "date_commande", "montant_total", "statut"],
    orderBy: "date_commande",
  },
  {
    key: "fournisseurs",
    label: "Fournisseurs",
    table: "fournisseurs",
    columns: ["fournisseur_id", "nom", "email", "telephone", "ville", "created_at"],
    orderBy: "nom",
  },
  {
    key: "employes",
    label: "Employés",
    table: "employes",
    columns: ["employe_id", "nom_complet", "email", "telephone", "poste", "date_embauche"],
    orderBy: "nom_complet",
  },
];

export async function fetchExportRows(entity: ExportEntity): Promise<Record<string, unknown>[]> {
  const select = entity.columns.join(",");
  let q = supabase.from(entity.table).select(select);
  if (entity.orderBy) q = q.order(entity.orderBy, { ascending: false });
  const { data, error } = await q.limit(10000);
  if (error) throw error;
  return (data ?? []) as unknown as Record<string, unknown>[];
}

function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export async function exportCSV(entity: ExportEntity, rows: Record<string, unknown>[]) {
  const Papa = (await import("papaparse")).default;
  const csv = Papa.unparse({
    fields: entity.columns,
    data: rows.map((r) => entity.columns.map((c) => r[c] ?? "")),
  });
  const stamp = new Date().toISOString().slice(0, 10);
  triggerDownload(
    new Blob([csv], { type: "text/csv;charset=utf-8;" }),
    `${entity.key}_${stamp}.csv`,
  );
}

export async function exportXLSX(entity: ExportEntity, rows: Record<string, unknown>[]) {
  const XLSX = await import("xlsx");
  const ws = XLSX.utils.json_to_sheet(rows, { header: entity.columns });
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, entity.label.slice(0, 31));
  const stamp = new Date().toISOString().slice(0, 10);
  const buf = XLSX.write(wb, { type: "array", bookType: "xlsx" });
  triggerDownload(
    new Blob([buf], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }),
    `${entity.key}_${stamp}.xlsx`,
  );
}

/**
 * SUPPRIMÉ (audit R5) — `exportFullBackupJSON` promettait une « sauvegarde
 * complète » alors qu'elle n'exportait que 8 entités plafonnées à 10 000 lignes,
 * sans utilisateurs ni fichiers de stockage. La seule sauvegarde faisant
 * autorité est le module /backup (toutes les tables + utilisateurs + storage +
 * empreinte SHA-256).
 */

