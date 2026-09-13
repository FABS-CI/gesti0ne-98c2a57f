// Équivalents SERVEUR (client admin, service role) des chargeurs de
// enrich-lignes.ts, utilisés uniquement par la route de téléchargement
// public sécurisé (aucune session utilisateur / RLS disponible à cet endroit).
// Ne PAS importer ce fichier depuis du code exécuté côté navigateur.
import type { DocBase, DocLigne } from "./fabsTemplates";
import type { DocClientInfo, DocTotals } from "./enrich-lignes";

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
  return rows.map((r) => {
    const qte = Number(r.quantite ?? 0);
    const pu = Number(r.prix_unitaire ?? 0);
    const remisePct = r.remise_pct != null ? Number(r.remise_pct) : 0;

    const montantBrutLigne = qte * pu;
    const montantRemise =
      r.montant_remise != null
        ? Number(r.montant_remise)
        : Math.round((montantBrutLigne * remisePct) / 100);

    const net = r.total_ligne != null ? Number(r.total_ligne) : montantBrutLigne - montantRemise;

    return {
      codeArticle: r.reference_produit ?? r.produits?.reference ?? undefined,
      reference: r.designation ?? undefined,
      cycle: (r.produits?.categorie ?? "").toUpperCase() || undefined,
      niveau: r.produits?.niveau ?? undefined,
      matiere: r.produits?.matiere ?? undefined,
      qte,
      prixUnitaire: pu,
      montant: net,
      remisePct,
      remiseMontant: montantRemise,
    };
  });
}

async function hydrateProduits(rows: RawLigne[]): Promise<RawLigne[]> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const ids = Array.from(new Set(rows.map((r) => r.produit_id).filter((v): v is string => !!v)));
  if (ids.length === 0) return rows;
  const { data } = await supabaseAdmin
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
    produits: r.produit_id ? (map.get(r.produit_id) ?? null) : null,
  }));
}

export async function loadCommandeDocLignesServer(commandeId: string): Promise<DocLigne[]> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data, error } = await supabaseAdmin
    .from("commande_lignes" as any)
    .select(
      "produit_id, designation, quantite, prix_unitaire, total_ligne, remise_pct, montant_remise, total_ht_ligne, reference_produit",
    )
    .eq("commande_id", commandeId);
  if (error) return [];
  const hydrated = await hydrateProduits((data ?? []) as unknown as RawLigne[]);
  return toDocLignes(hydrated);
}

export async function loadProformaDocLignesServer(proformaId: string): Promise<DocLigne[]> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data: pf } = await supabaseAdmin
    .from("proformas" as any)
    .select("commande_id")
    .eq("proforma_id", proformaId)
    .maybeSingle();
  if ((pf as any)?.commande_id) return loadCommandeDocLignesServer((pf as any).commande_id);

  const { data, error } = await supabaseAdmin
    .from("proforma_lignes" as any)
    .select("produit_id, designation, quantite, prix_unitaire, total_ligne")
    .eq("proforma_id", proformaId);
  if (error) return [];
  const hydrated = await hydrateProduits((data ?? []) as unknown as RawLigne[]);
  return toDocLignes(hydrated);
}

export async function loadFactureDocLignesServer(factureId: string): Promise<DocLigne[]> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data: f } = await supabaseAdmin
    .from("factures" as any)
    .select("commande_id")
    .eq("facture_id", factureId)
    .maybeSingle();
  if (!(f as any)?.commande_id) return [];
  return loadCommandeDocLignesServer((f as any).commande_id);
}

export async function loadBLDocLignesServer(blId: string): Promise<DocLigne[]> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data: bl } = await supabaseAdmin
    .from("bons_livraison" as any)
    .select("commande_id")
    .eq("bl_id", blId)
    .maybeSingle();
  if (!(bl as any)?.commande_id) return [];
  return loadCommandeDocLignesServer((bl as any).commande_id);
}

export async function loadClientDocInfoServer(
  clientId: string | null | undefined,
): Promise<DocClientInfo> {
  if (!clientId) return {} as DocClientInfo;
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("clients" as any)
    .select("reference, nom, representant, telephone, email, adresse, ville, quartier, pays, nif")
    .eq("client_id", clientId)
    .maybeSingle();
  if (!data) return {};
  const c = data as any;
  return {
    clientNom: c.nom,
    codeClient: c.reference,
    representant: c.representant,
    representantTel: c.telephone,
    clientTel: c.telephone,
    emailClient: c.email,
    adresseClient: c.adresse,
    villeClient: c.ville,
    communeClient: c.quartier,
    paysClient: c.pays,
    ncc: c.nif,
  };
}

export async function loadClientInfoForCommandeServer(commandeId: string): Promise<DocClientInfo> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("commandes" as any)
    .select("client_id")
    .eq("commande_id", commandeId)
    .maybeSingle();
  return loadClientDocInfoServer((data as any)?.client_id);
}

export async function loadClientInfoForProformaServer(proformaId: string): Promise<DocClientInfo> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("proformas" as any)
    .select("client_id")
    .eq("proforma_id", proformaId)
    .maybeSingle();
  return loadClientDocInfoServer((data as any)?.client_id);
}

export async function loadClientInfoForFactureServer(factureId: string): Promise<DocClientInfo> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("factures" as any)
    .select("client_id, commande_id")
    .eq("facture_id", factureId)
    .maybeSingle();
  const d = data as any;
  if (d?.client_id) return loadClientDocInfoServer(d.client_id);
  if (d?.commande_id) return loadClientInfoForCommandeServer(d.commande_id);
  return {};
}

export async function loadClientInfoForBLServer(blId: string): Promise<DocClientInfo> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("bons_livraison" as any)
    .select("commande_id")
    .eq("bl_id", blId)
    .maybeSingle();
  if (!(data as any)?.commande_id) return {};
  return loadClientInfoForCommandeServer((data as any).commande_id);
}

export async function loadCommandeTotalsServer(commandeId: string): Promise<DocTotals> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("commandes" as any)
    .select(
      "total_ht_brut, total_remises_lignes, total_ht_net, remise_globale_pct, remise_globale_montant, taux_tva, montant_tva, montant_ttc, net_a_payer, montant_total",
    )
    .eq("commande_id", commandeId)
    .maybeSingle();
  if (!data) return {};
  const d = data as any;
  const brut = Number(d.total_ht_brut ?? 0);
  const remiseLigne = Number(d.total_remises_lignes ?? 0);
  const remiseGlobale = Number(d.remise_globale_montant ?? 0);
  const ht = Number(d.total_ht_net ?? brut - remiseLigne - remiseGlobale);
  return {
    totalVente: brut || undefined,
    remiseLigneTotal: remiseLigne || undefined,
    remiseGlobalePct: Number(d.remise_globale_pct ?? 0) || undefined,
    remiseGlobale: remiseGlobale || undefined,
    montantHT: ht || undefined,
    tvaPct: 0,
    tva: 0,
    totalTTC: ht || undefined,
  };
}

export async function loadFactureTotalsServer(factureId: string): Promise<DocTotals> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("factures" as any)
    .select("commande_id")
    .eq("facture_id", factureId)
    .maybeSingle();
  if (!(data as any)?.commande_id) return {};
  return loadCommandeTotalsServer((data as any).commande_id);
}

export async function loadProformaTotalsServer(proformaId: string): Promise<DocTotals> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("proformas" as any)
    .select("commande_id")
    .eq("proforma_id", proformaId)
    .maybeSingle();
  if (!(data as any)?.commande_id) return {};
  return loadCommandeTotalsServer((data as any).commande_id);
}
