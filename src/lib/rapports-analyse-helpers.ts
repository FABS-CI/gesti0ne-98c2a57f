import type { ProduitLigneRapport } from "@/lib/rapports-api";

export const PRODUITS_HEADERS = [
  "Code",
  "Désignation",
  "Niveau",
  "Catégorie",
  "PU",
  "Qté vendue",
  "Qté facturée",
  "Nb factures",
  "Nb clients",
  "CA",
  "Remises",
  "Retours",
  "Stock actuel",
  "Stock initial",
  "Stock restant",
  "% CA",
  "Rang",
];

export const PRODUITS_COLUMNS: Array<[string, string]> = [
  ["code", "Code"],
  ["titre", "Désignation"],
  ["", "Niveau"],
  ["", "Catégorie"],
  ["", "PU"],
  ["qte", "Qté vendue"],
  ["", "Qté fact."],
  ["", "Nb fact."],
  ["", "Nb clients"],
  ["ca", "CA"],
  ["", "Remises"],
  ["", "Retours"],
  ["stock", "Stock actuel"],
  ["", "Stock init."],
  ["", "Stock rest."],
  ["", "% CA"],
  ["", "Rang"],
];

export function produitsRowsForExport(rows: ProduitLigneRapport[]) {
  return rows.map((r) => [
    r.code ?? "",
    r.titre,
    r.niveau ?? "",
    r.categorie ?? "",
    r.prix_unitaire,
    r.qte_vendue,
    r.qte_facturee,
    r.nb_factures,
    r.nb_clients,
    r.ca,
    r.remises,
    r.qte_retournee,
    r.stock_actuel,
    r.stock_initial,
    r.stock_restant,
    r.pct_ca,
    r.rang,
  ]);
}
