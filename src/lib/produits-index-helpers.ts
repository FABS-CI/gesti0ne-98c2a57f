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
    "Code article",
    "Désignation",
    "Prix achat (FCFA)",
    "Prix vente (FCFA)",
    "Stock",
  ];
  const rows = all.map((prod, i) => {
    const parts = [prod.titre, prod.auteur || null].filter(Boolean);
    return [
      String(i + 1),
      prod.reference,
      parts.join(" — "),

      canSeeSensitive ? formatFCFA(prod.prix_achat, false) : "—",
      canSeeSensitive ? formatFCFA(prod.prix_vente, false) : "—",
      String(prod.stock ?? 0),
    ];
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
  await exportCsv(`liste_produits_fabs_${new Date().toISOString().slice(0, 10)}`, headers, rows, {
    columnStyles: {
      0: { cellWidth: 10, halign: "center", fontStyle: "bold", overflow: "visible" },
      1: { cellWidth: 28, fontStyle: "bold", overflow: "visible" },
      2: { cellWidth: "auto" },
      3: { cellWidth: 26, halign: "right" },
      4: { cellWidth: 26, halign: "right", fontStyle: "bold" },
      5: { cellWidth: 18, halign: "center", fontStyle: "bold" },
    },

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
