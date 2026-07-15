import { supabase } from "@/integrations/supabase/client";
import type { Json } from "@/integrations/supabase/types";
import type { Client } from "@/lib/clients-api";

export type CrmFilters = {
  q?: string;
  produits?: string[];
  niveaux?: string[];
  categories?: string[];
  types?: string[];
  villes?: string[];
  representant?: string;
  from?: string; // YYYY-MM-DD
  to?: string;
  actif?: boolean;
};

export type ClientCrm = Client & {
  nb_commandes: number | null;
  ca_total: number | null;
  qte_totale: number | null;
  ticket_moyen: number | null;
  premiere_commande: string | null;
  derniere_commande: string | null;
  top_produit: string | null;
  top_categorie: string | null;
  top_niveau: string | null;
};

export type CrmSearchResult = { total: number; items: ClientCrm[] };

export async function searchClientsCrm(
  filters: CrmFilters,
  page = 1,
  pageSize = 20,
): Promise<CrmSearchResult> {
  const { data, error } = await supabase.rpc("search_clients_crm", {
    _filters: filters as unknown as Json,
    _limit: pageSize,
    _offset: (page - 1) * pageSize,
  });
  if (error) throw error;
  const res = (data ?? { total: 0, items: [] }) as unknown as CrmSearchResult;
  return { total: res.total ?? 0, items: res.items ?? [] };
}

export type HistoriqueLigne = {
  commande_id: string;
  commande_reference: string;
  date_commande: string;
  commande_statut: string;
  produit_id: string | null;
  produit_titre: string;
  reference_produit: string | null;
  niveau: string | null;
  categorie: string | null;
  quantite: number;
  prix_unitaire: number;
  remise_pct: number;
  total_ligne: number;
};

export async function getClientHistorique(clientId: string): Promise<HistoriqueLigne[]> {
  const { data, error } = await supabase.rpc("client_historique", { _client_id: clientId });
  if (error) throw error;
  return (data ?? []) as HistoriqueLigne[];
}

export type DashboardBucket = { label: string; ca: number; qte?: number; nb?: number };
export type CrmDashboard = {
  ca_total: number;
  nb_commandes: number;
  nb_clients: number;
  par_niveau: DashboardBucket[];
  par_categorie: DashboardBucket[];
  par_ville: DashboardBucket[];
  par_type_client: DashboardBucket[];
  top_produits: DashboardBucket[];
  flop_produits: DashboardBucket[];
  ca_mensuel: { mois: string; ca: number; nb: number }[];
  top_clients: {
    client_id: string;
    client_nom: string;
    type_client: string | null;
    ville: string | null;
    ca: number;
    nb: number;
  }[];
  top_representants: { label: string; ca: number; nb_clients: number }[];
};

export async function getCrmDashboard(from?: string, to?: string): Promise<CrmDashboard> {
  const { data, error } = await supabase.rpc("crm_dashboard", {
    _from: from,
    _to: to,
  });
  if (error) throw error;
  return data as unknown as CrmDashboard;
}

/** Facettes pour peupler les listes déroulantes des filtres. */
export async function getCrmFacets() {
  const [prod, fac] = await Promise.all([
    supabase
      .from("produits")
      .select("produit_id,titre,niveau,categorie")
      .eq("actif", true)
      .order("pin_order", { ascending: true })
      .order("niveau_ordre", { ascending: true })
      .order("titre", { ascending: true }),
    // Agrégat serveur : distincts calculés côté base (au lieu de télécharger tous les clients actifs)
    supabase.rpc("clients_facets"),
  ]);
  if (prod.error) throw prod.error;
  if (fac.error) throw fac.error;
  const facets = (fac.data ?? { villes: [], representants: [], types: [] }) as {
    villes: string[];
    representants: string[];
    types: string[];
  };
  const uniq = <T>(arr: (T | null | undefined)[]) =>
    [...new Set(arr.filter((x): x is T => !!x))] as T[];
  return {
    produits: (prod.data ?? []).map((p) => ({
      id: p.produit_id,
      titre: p.titre,
      niveau: p.niveau,
      categorie: p.categorie,
    })),
    niveaux: uniq((prod.data ?? []).map((p) => p.niveau)).sort(),
    categories: uniq((prod.data ?? []).map((p) => p.categorie)).sort(),
    villes: facets.villes ?? [],
    representants: facets.representants ?? [],
    types: facets.types ?? [],
  };
}
