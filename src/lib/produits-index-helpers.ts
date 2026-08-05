import { type Produit, type ProduitInput, listProduits } from "@/lib/produits-api";
import { CATEGORIE_LABEL } from "@/lib/company";
import { formatFCFA } from "@/lib/format";
import { exportCsv } from "@/lib/export-csv";

export const PAGE_SIZE = 50;

export const PRIVILEGED_ROLES = [
  "super_admin",
  "directeur_general",
  "directeur_commercial",
  "gestionnaire_stock",
  "responsable_magasinier",
  "service_logistique",
] as const;

export const emptyForm: ProduitInput = {
  titre: "",
  isbn: "",
  categorie: "manuel",
  niveau: "",
  matiere: "",
  auteur: "",
  editeur: "",
  prix_vente: 0,
  prix_achat: 0,
  seuil_alerte: 10,
};

export interface ExportFilters {
  q?: string;
  categorie?: string;
  niveau?: string;
  actif?: boolean;
}

export async function exportProduitsPdf(filters: ExportFilters, canSeeSensitive: boolean) {
  const all: Produit[] = [];
  const size = 500;
  let p = 1;
  while (true) {
    const res = await listProduits({ ...filters, page: p, pageSize: size });
    all.push(...res.items);
    if (all.length >= res.total || res.items.length < size) break;
    p += 1;
  }
  const headers = [
    "N°",
    "Réf.",
    "Désignation",
    ...(canSeeSensitive ? ["Prix achat", "Prix vente", "Valeur vente"] : []),
    "Stock",
  ];

  const rows = all.map((prod, i) => {
    const parts = [prod.titre, prod.auteur || null].filter(Boolean);
    const row = [
      String(i + 1),
      prod.reference,
      parts.join(" — "),
    ];

    if (canSeeSensitive) {
      row.push(formatFCFA(prod.prix_achat, false));
      row.push(formatFCFA(prod.prix_vente, false));
      row.push(formatFCFA(prod.stock * prod.prix_vente, false));
    }

    row.push(String(prod.stock ?? 0));
    return row;
  });
  const totalAchat = all.reduce(
    (s, x) => s + (Number(x.prix_achat) || 0) * (Number(x.stock) || 0),
    0,
  );
  const totalVente = all.reduce(
    (s, x) => s + (Number(x.prix_vente) || 0) * (Number(x.stock) || 0),
    0,
  );
  const qte = all.reduce((s, x) => s + (Number(x.stock) || 0), 0);
  const columnStyles: Record<number, any> = {
    0: { cellWidth: 10, halign: "center", fontStyle: "bold" },
    1: { cellWidth: 25, fontStyle: "bold" },
    2: { cellWidth: "auto" },
  };

  if (canSeeSensitive) {
    columnStyles[3] = { cellWidth: 22, halign: "right" }; // Achat
    columnStyles[4] = { cellWidth: 22, halign: "right" }; // Vente
    columnStyles[5] = { cellWidth: 25, halign: "right", fontStyle: "bold" }; // Valeur Vente
    columnStyles[6] = { cellWidth: 15, halign: "center", fontStyle: "bold" }; // Stock
  } else {
    columnStyles[3] = { cellWidth: 18, halign: "center", fontStyle: "bold" }; // Stock
  }

  await exportCsv(`liste_produits_fabs_${new Date().toISOString().slice(0, 10)}`, headers, rows, {
    columnStyles,

    pageTitle: "LISTE DES PRODUITS",
    summary: [
      { label: "Nombre total de références", value: String(all.length) },
      { label: "Quantité totale en stock", value: `${qte} ex.` },
      ...(canSeeSensitive
        ? [
            { label: "Valeur totale (Prix d'achat)", value: formatFCFA(totalAchat) },
            { label: "Valeur totale (Prix de vente)", value: formatFCFA(totalVente) },
          ]
        : []),
    ],
  });
  return all.length;
}
