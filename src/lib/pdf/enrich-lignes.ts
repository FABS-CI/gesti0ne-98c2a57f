// Enrichit les lignes de documents (factures, proformas, commandes, BL)
// avec cycle / niveau / matière en joignant produits.categorie pour
// activer le regroupement V10 par cycle scolaire dans les PDF.
import { supabase } from "@/integrations/supabase/client";
import type { DocBase, DocLigne } from "./fabsTemplates";

type RawLigne = {
  produit_id: string | null;
  designation: string | null;
  quantite: number | null;
  prix_unitaire: number | null;
  total_ligne: number | null;
  remise_pct?: number | null;
  montant_remise?: number | null;
  total_ht_ligne?: number | null;
  reference_produit?: string | null;
  produits?: {
    categorie: string | null;
    niveau: string | null;
    matiere: string | null;
    reference: string | null;
  } | null;
};

function toDocLignes(rows: RawLigne[]): DocLigne[] {
  return rows.map((r) => ({
    codeArticle: r.reference_produit ?? r.produits?.reference ?? undefined,
    reference: r.designation ?? undefined,
    cycle: (r.produits?.categorie ?? "").toUpperCase() || undefined,
    niveau: r.produits?.niveau ?? undefined,
    matiere: r.produits?.matiere ?? undefined,
    qte: Number(r.quantite ?? 0),
    prixUnitaire: Number(r.prix_unitaire ?? 0),
    montant: Number(r.total_ligne ?? (r.quantite ?? 0) * (r.prix_unitaire ?? 0)),
    remisePct: r.remise_pct != null ? Number(r.remise_pct) : undefined,
    remiseMontant: r.montant_remise != null ? Number(r.montant_remise) : undefined,
  }));
}

/**
 * Hydrate les lignes avec les infos produits (categorie, niveau, matiere,
 * reference) via une requête séparée. La relation FK n'étant pas déclarée
 * dans PostgREST, un `select("produits(...)")` renvoie une 400 et vidait
 * toutes les lignes des PDF (Bon de commande, Facture, BL…).
 */
async function hydrateProduits(rows: RawLigne[]): Promise<RawLigne[]> {
  const ids = Array.from(
    new Set(rows.map((r) => r.produit_id).filter((v): v is string => !!v)),
  );
  if (ids.length === 0) return rows;
  const { data } = await supabase
    .from("produits")
    .select("produit_id, reference, categorie, niveau, matiere")
    .in("produit_id", ids);
  const map = new Map<string, RawLigne["produits"]>();
  for (const p of (data ?? []) as Array<{
    produit_id: string;
    reference: string | null;
    categorie: string | null;
    niveau: string | null;
    matiere: string | null;
  }>) {
    map.set(p.produit_id, {
      categorie: p.categorie,
      niveau: p.niveau,
      matiere: p.matiere,
      reference: p.reference,
    });
  }
  return rows.map((r) => ({
    ...r,
    produits: r.produit_id ? map.get(r.produit_id) ?? null : null,
  }));
}

/** Lignes enrichies d'une proforma (via proforma_lignes + produits). */
export async function loadProformaDocLignes(proformaId: string): Promise<DocLigne[]> {
  // Priorité aux lignes de la commande liée pour bénéficier des remises et
  // du code article. Fallback sur proforma_lignes si aucune commande liée.
  const { data: pf } = await supabase
    .from("proformas")
    .select("commande_id")
    .eq("proforma_id", proformaId)
    .maybeSingle();
  if (pf?.commande_id) {
    return loadCommandeDocLignes(pf.commande_id);
  }
  const { data, error } = await supabase
    .from("proforma_lignes")
    .select("produit_id, designation, quantite, prix_unitaire, total_ligne")
    .eq("proforma_id", proformaId);
  if (error) return [];
  const hydrated = await hydrateProduits((data ?? []) as unknown as RawLigne[]);
  return toDocLignes(hydrated);
}

/** Lignes enrichies d'une commande (via commande_lignes + produits). */
export async function loadCommandeDocLignes(commandeId: string): Promise<DocLigne[]> {
  const { data, error } = await supabase
    .from("commande_lignes")
    .select(
      "produit_id, designation, quantite, prix_unitaire, total_ligne, remise_pct, montant_remise, total_ht_ligne, reference_produit",
    )
    .eq("commande_id", commandeId);
  if (error) return [];
  const hydrated = await hydrateProduits((data ?? []) as unknown as RawLigne[]);
  return toDocLignes(hydrated);
}

/**
 * Lignes enrichies d'une facture.
 * Les factures n'ont pas de table de lignes propre : on remonte
 * via commande_id → commande_lignes → produits.
 */
export async function loadFactureDocLignes(factureId: string): Promise<DocLigne[]> {
  const { data: f } = await supabase
    .from("factures")
    .select("commande_id")
    .eq("facture_id", factureId)
    .maybeSingle();
  if (!f?.commande_id) return [];
  return loadCommandeDocLignes(f.commande_id);
}

/**
 * Informations complètes du client à afficher dans le bloc CLIENT des
 * documents commerciaux (BC, PF, FC, BL, BR, AV, RP…).
 * Retourne une partie de DocBase à fusionner (`{ ...clientInfo, ... }`).
 */
export type DocClientInfo = Pick<
  DocBase,
  | "clientNom"
  | "clientTel"
  | "codeClient"
  | "representant"
  | "representantTel"
  | "emailClient"
  | "adresseClient"
  | "villeClient"
  | "communeClient"
  | "paysClient"
  | "ncc"
>;

export async function loadClientDocInfo(
  clientId: string | null | undefined,
): Promise<DocClientInfo> {
  if (!clientId) return {};
  const { data } = await supabase
    .from("clients")
    .select(
      "reference, nom, representant, telephone, telephone2, email, adresse, ville, quartier, pays, nif",
    )
    .eq("client_id", clientId)
    .maybeSingle();
  if (!data) return {};
  return {
    clientNom: data.nom,
    codeClient: data.reference,
    representant: data.representant,
    representantTel: data.telephone ?? data.telephone2,
    clientTel: data.telephone2 ?? data.telephone,
    emailClient: data.email,
    adresseClient: data.adresse,
    villeClient: data.ville,
    communeClient: data.quartier,
    paysClient: data.pays,
    ncc: data.nif,
  };
}

/** Récupère les infos client à partir d'une commande. */
export async function loadClientInfoForCommande(commandeId: string): Promise<DocClientInfo> {
  const { data } = await supabase
    .from("commandes")
    .select("client_id")
    .eq("commande_id", commandeId)
    .maybeSingle();
  return loadClientDocInfo(data?.client_id);
}

/** Récupère les infos client à partir d'une proforma. */
export async function loadClientInfoForProforma(proformaId: string): Promise<DocClientInfo> {
  const { data } = await supabase
    .from("proformas")
    .select("client_id")
    .eq("proforma_id", proformaId)
    .maybeSingle();
  return loadClientDocInfo(data?.client_id);
}

/** Récupère les infos client à partir d'une facture. */
export async function loadClientInfoForFacture(factureId: string): Promise<DocClientInfo> {
  const { data } = await supabase
    .from("factures")
    .select("client_id, commande_id")
    .eq("facture_id", factureId)
    .maybeSingle();
  if (data?.client_id) return loadClientDocInfo(data.client_id);
  if (data?.commande_id) return loadClientInfoForCommande(data.commande_id);
  return {};
}

/** Récupère les infos client à partir d'un bon de livraison (via commande). */
export async function loadClientInfoForBL(blId: string): Promise<DocClientInfo> {
  const { data } = await supabase
    .from("bons_livraison")
    .select("commande_id")
    .eq("bl_id", blId)
    .maybeSingle();
  if (!data?.commande_id) return {};
  return loadClientInfoForCommande(data.commande_id);
}

/** Récupère les infos client à partir d'un bon de retour (via facture). */
export async function loadClientInfoForBR(brId: string): Promise<DocClientInfo> {
  const { data } = await supabase
    .from("bons_retour")
    .select("facture_id")
    .eq("br_id", brId)
    .maybeSingle();
  if (!data?.facture_id) return {};
  return loadClientInfoForFacture(data.facture_id);
}

/**
 * Totaux financiers d'une commande à propager dans les PDF
 * (Commande, Proforma, Facture, BL). Toutes les valeurs proviennent
 * de `commandes` et reflètent fidèlement ce qui a été saisi.
 */
export type DocTotals = Pick<
  DocBase,
  | "totalVente"
  | "remiseLigneTotal"
  | "remiseGlobalePct"
  | "remiseGlobale"
  | "montantHT"
  | "tvaPct"
  | "tva"
  | "totalTTC"
>;

export async function loadCommandeTotals(commandeId: string): Promise<DocTotals> {
  const { data } = await supabase
    .from("commandes")
    .select(
      "total_ht_brut, total_remises_lignes, total_ht_net, remise_globale_pct, remise_globale_montant, taux_tva, montant_tva, montant_ttc, net_a_payer, montant_total",
    )
    .eq("commande_id", commandeId)
    .maybeSingle();
  if (!data) return {};
  const brut = Number(data.total_ht_brut ?? 0);
  const remiseLigne = Number(data.total_remises_lignes ?? 0);
  const remiseGlobale = Number(data.remise_globale_montant ?? 0);
  const ht = Number(data.total_ht_net ?? brut - remiseLigne - remiseGlobale);
  // TVA supprimée de l'ERP : on force les montants à 0 même si l'historique
  // en base contient encore un taux/montant (ancienne saisie à 18 %).
  // TVA supprimée : le total doit rester strictement égal au HT, même si
  // l'historique en base stocke encore un net_a_payer/montant_total TTC.
  const tvaPct = 0;
  const tva = 0;
  const ttc = ht;
  return {
    totalVente: brut || undefined,
    remiseLigneTotal: remiseLigne || undefined,
    remiseGlobalePct: Number(data.remise_globale_pct ?? 0) || undefined,
    remiseGlobale: remiseGlobale || undefined,
    montantHT: ht || undefined,
    tvaPct: tvaPct || undefined,
    tva: tva || undefined,
    totalTTC: ttc || undefined,
  };
}

export async function loadFactureTotals(factureId: string): Promise<DocTotals> {
  const { data } = await supabase
    .from("factures")
    .select("commande_id")
    .eq("facture_id", factureId)
    .maybeSingle();
  if (!data?.commande_id) return {};
  return loadCommandeTotals(data.commande_id);
}

export async function loadProformaTotals(proformaId: string): Promise<DocTotals> {
  const { data } = await supabase
    .from("proformas")
    .select("commande_id")
    .eq("proforma_id", proformaId)
    .maybeSingle();
  if (!data?.commande_id) return {};
  return loadCommandeTotals(data.commande_id);
}
