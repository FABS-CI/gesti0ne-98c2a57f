import { exportCsv } from "@/lib/export-csv";
import { TYPES_INVENTAIRE, type InventaireLigne } from "@/lib/inventaires-api";

type Inv = {
  type_inventaire: string;
  date_inventaire: string;
  depots?: { nom: string | null } | null;
};

type Live = { ligne: InventaireLigne; compte: number; ecart: number };

export function exportInventaireCsv(
  inv: Inv,
  ecartsLive: Live[],
  obs: Record<string, string>,
  totaux: { nbEcarts: number },
) {
  const headers = [
    "Référence",
    "Désignation",
    "Théorique",
    "Compté",
    "Écart",
    "Val. Achat",
    "Val. Vente",
    "Val. Écart",
    "Observation",
  ];
  const rows = ecartsLive.map(({ ligne, compte, ecart }) => [
    ligne.reference_produit ?? "",
    ligne.designation,
    ligne.stock_theorique,
    compte,
    ecart,
    Number(ligne.produits?.prix_achat ?? ligne.valeur_unitaire ?? 0),
    Number(ligne.produits?.prix_vente ?? 0),
    ecart * Number(ligne.valeur_unitaire),
    obs[ligne.ligne_id] ?? "",
  ]);
  const valeurEcart = ecartsLive.reduce(
    (s, { ligne, ecart }) => s + ecart * Number(ligne.valeur_unitaire),
    0,
  );
  const valeurAchat = ecartsLive.reduce(
    (s, { ligne, compte }) =>
      s + compte * Number(ligne.produits?.prix_achat ?? ligne.valeur_unitaire ?? 0),
    0,
  );
  const valeurVente = ecartsLive.reduce(
    (s, { ligne, compte }) => s + compte * Number(ligne.produits?.prix_vente ?? 0),
    0,
  );
  const fmt = (n: number) =>
    new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(n) + " FCFA";
  const typeLabel =
    TYPES_INVENTAIRE.find((t) => t.value === inv.type_inventaire)?.label ?? inv.type_inventaire;
  const dateFr = new Date(inv.date_inventaire).toLocaleDateString("fr-FR");
  const dateSlug = inv.date_inventaire.slice(0, 10);
  const depotSlug = inv.depots?.nom
    ? "_" + inv.depots.nom.toLowerCase().replace(/[^a-z0-9]+/gi, "-")
    : "";
  exportCsv(
    `inventaire_${typeLabel.toLowerCase().replace(/[^a-z0-9]+/gi, "-")}${depotSlug}_${dateSlug}`,
    headers,
    rows,
    {
      pageTitle: `INVENTAIRE ${typeLabel.toUpperCase()}${
        inv.depots?.nom ? " — " + inv.depots.nom.toUpperCase() : ""
      } DU ${dateFr}`,
      summary: [
        { label: "Nombre de lignes", value: String(ecartsLive.length) },
        { label: "Lignes avec écart", value: String(totaux.nbEcarts) },
        { label: "Valeur totale d'achat", value: fmt(valeurAchat) },
        { label: "Valeur totale de vente", value: fmt(valeurVente) },
        { label: "Valeur des écarts", value: fmt(valeurEcart) },
      ],
    },
  );
}
