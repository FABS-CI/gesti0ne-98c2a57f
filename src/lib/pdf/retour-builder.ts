// Construction du DocBase pour la génération du Bon de Retour PDF.
// Enrichit chaque ligne avec le prix unitaire (facture liée ou produit) et
// remonte les infos client complètes.
import { supabase } from "@/integrations/supabase/client";
import type { DocBase, DocLigne } from "./fabsTemplates";
import { loadClientDocInfo } from "./enrich-lignes";
import { getRetour, type RetourWithLignes } from "@/lib/retours-api";

async function loadPrixMap(
  factureId: string | null,
  produitIds: string[],
): Promise<Map<string, number>> {
  const prices = new Map<string, number>();

  // 1) Prix vendus sur la facture liée (via la commande)
  if (factureId) {
    const { data: fac } = await supabase
      .from("factures")
      .select("commande_id")
      .eq("facture_id", factureId)
      .maybeSingle();
    if (fac?.commande_id) {
      const { data: lignes } = await supabase
        .from("commande_lignes")
        .select("produit_id, prix_unitaire")
        .eq("commande_id", fac.commande_id);
      for (const l of (lignes ?? []) as Array<{
        produit_id: string | null;
        prix_unitaire: number | null;
      }>) {
        if (l.produit_id && l.prix_unitaire != null) {
          prices.set(l.produit_id, Number(l.prix_unitaire));
        }
      }
    }
  }

  // 2) Fallback : prix de vente courant du produit
  const missing = produitIds.filter((id) => !prices.has(id));
  if (missing.length > 0) {
    const { data: prods } = await supabase
      .from("produits")
      .select("produit_id, prix_vente, categorie, niveau, matiere, reference")
      .in("produit_id", missing);
    for (const p of (prods ?? []) as Array<{
      produit_id: string;
      prix_vente: number | null;
    }>) {
      if (p.prix_vente != null) prices.set(p.produit_id, Number(p.prix_vente));
    }
  }
  return prices;
}

async function loadProduitsMeta(
  ids: string[],
): Promise<Map<string, { cycle?: string; niveau?: string; matiere?: string; reference?: string }>> {
  const map = new Map<string, { cycle?: string; niveau?: string; matiere?: string; reference?: string }>();
  if (ids.length === 0) return map;
  const { data } = await supabase
    .from("produits")
    .select("produit_id, categorie, niveau, matiere, reference")
    .in("produit_id", ids);
  for (const p of (data ?? []) as Array<{
    produit_id: string;
    categorie: string | null;
    niveau: string | null;
    matiere: string | null;
    reference: string | null;
  }>) {
    map.set(p.produit_id, {
      cycle: (p.categorie ?? "").toUpperCase() || undefined,
      niveau: p.niveau ?? undefined,
      matiere: p.matiere ?? undefined,
      reference: p.reference ?? undefined,
    });
  }
  return map;
}

export async function buildRetourDocBase(retourId: string): Promise<DocBase> {
  const retour = await getRetour(retourId);
  if (!retour) throw new Error("Retour introuvable");
  return buildRetourDocBaseFrom(retour);
}

export async function buildRetourDocBaseFrom(retour: RetourWithLignes): Promise<DocBase> {
  const produitIds = Array.from(
    new Set(retour.lignes.map((l) => l.produit_id).filter((v): v is string => !!v)),
  );
  const [prices, meta, clientInfo] = await Promise.all([
    loadPrixMap(retour.facture_id, produitIds),
    loadProduitsMeta(produitIds),
    loadClientDocInfo(retour.client_id),
  ]);

  let totalHT = 0;
  const lignes: DocLigne[] = retour.lignes.map((l) => {
    const pu = l.produit_id ? prices.get(l.produit_id) ?? 0 : 0;
    const montant = pu * Number(l.quantite ?? 0);
    totalHT += montant;
    const m = l.produit_id ? meta.get(l.produit_id) : undefined;
    return {
      codeArticle: l.reference_produit ?? m?.reference ?? undefined,
      reference: l.designation,
      cycle: m?.cycle,
      niveau: m?.niveau,
      matiere: m?.matiere,
      qteRetournee: Number(l.quantite ?? 0),
      motif: l.motif ?? undefined,
      prixUnitaire: pu || undefined,
      montant: montant || undefined,
    };
  });

  // Priorité aux infos saisies sur le retour, fallback sur la fiche client
  return {
    reference: retour.numero ?? retour.reference,
    date: retour.date_retour,
    clientNom: retour.etablissement ?? retour.client_nom ?? clientInfo.clientNom ?? null,
    clientTel: retour.telephone ?? clientInfo.clientTel ?? null,
    representant: retour.representant_nom ?? clientInfo.representant ?? null,
    representantTel: clientInfo.representantTel ?? null,
    codeClient: clientInfo.codeClient ?? null,
    adresseClient: retour.adresse ?? clientInfo.adresseClient ?? null,
    villeClient: retour.ville ?? clientInfo.villeClient ?? null,
    communeClient: clientInfo.communeClient ?? null,
    paysClient: clientInfo.paysClient ?? null,
    emailClient: clientInfo.emailClient ?? null,
    ncc: clientInfo.ncc ?? null,
    lignes,
    totalVente: totalHT || undefined,
    montantHT: totalHT || undefined,
    totalTTC: totalHT || undefined,
    statut:
      retour.statut === "annule"
        ? { label: "Annulé", color: "#DC2626" }
        : { label: "Accepté", color: "#10B981" },
  };
}
