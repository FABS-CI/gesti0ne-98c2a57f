import { supabase } from "@/integrations/supabase/client";
import { getDepotDefautId } from "@/lib/parametres-api";
import { assertPermission } from "@/lib/rbac-api";

export const STATUTS_RETOUR = [
  { value: "accepte", label: "Accepté", color: "#10B981" },
  { value: "annule", label: "Annulé", color: "#EF4444" },
] as const;

export const STATUT_RETOUR_LABEL: Record<string, { label: string; color: string }> =
  Object.fromEntries(STATUTS_RETOUR.map((s) => [s.value, { label: s.label, color: s.color }]));

export type Retour = {
  retour_id: string;
  reference: string;
  numero: string | null;
  date_retour: string;
  client_id: string | null;
  client_nom: string | null;
  etablissement: string | null;
  representant_nom: string | null;
  telephone: string | null;
  ville: string | null;
  adresse: string | null;
  depot_id: string | null;
  total_quantite: number;
  nb_produits: number;
  observations: string | null;
  notes: string | null;
  motif: string | null;
  statut: string;
  facture_id: string | null;
  livraison_id: string | null;
  commande_id: string | null;
  montant: number;
  created_by: string | null;
  created_by_nom: string | null;
  created_at: string;
  updated_at: string;
};

export type RetourLigne = {
  ligne_id: string;
  retour_id: string;
  produit_id: string | null;
  reference_produit: string | null;
  designation: string;
  quantite: number;
  motif: string | null;
  created_at: string;
};

export type RetourWithLignes = Retour & { lignes: RetourLigne[] };

export type RetourLigneInput = {
  produit_id: string;
  reference_produit?: string | null;
  designation: string;
  quantite: number;
  motif?: string | null;
};

export type RetourInput = {
  date_retour?: string;
  client_id: string;
  etablissement?: string | null;
  representant_nom?: string | null;
  telephone?: string | null;
  ville?: string | null;
  adresse?: string | null;
  depot_id?: string | null;
  observations?: string | null;
  notes?: string | null;
  facture_id?: string | null;
  livraison_id?: string | null;
  lignes: RetourLigneInput[];
};

export type ListRetoursParams = {
  q?: string;
  statut?: string;
  client_id?: string;
  ville?: string;
  exerciceId?: string | null;
};

export async function listRetours(params: ListRetoursParams = {}): Promise<Retour[]> {
  let query = supabase
    .from("retours")
    .select("*")
    .order("date_retour", { ascending: false })
    .order("created_at", { ascending: false });

  if (params.exerciceId) query = query.eq("exercice_id", params.exerciceId);
  if (params.statut && params.statut !== "all") query = query.eq("statut", params.statut);
  if (params.client_id) query = query.eq("client_id", params.client_id);
  if (params.ville) query = query.ilike("ville", `%${params.ville}%`);
  if (params.q && params.q.trim()) {
    const t = `%${params.q.trim()}%`;
    query = query.or(
      `numero.ilike.${t},reference.ilike.${t},etablissement.ilike.${t},client_nom.ilike.${t},representant_nom.ilike.${t},ville.ilike.${t}`,
    );
  }
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as Retour[];
}

export async function getRetour(id: string): Promise<RetourWithLignes | null> {
  const { data, error } = await supabase
    .from("retours")
    .select("*")
    .eq("retour_id", id)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  const { data: lignes, error: errL } = await supabase
    .from("retour_lignes")
    .select("*")
    .eq("retour_id", id)
    .order("created_at", { ascending: true });
  if (errL) throw errL;
  return { ...(data as Retour), lignes: (lignes ?? []) as RetourLigne[] };
}

export async function creerRetour(input: RetourInput): Promise<Retour> {
  await assertPermission("retours.creer");
  const depot_id = input.depot_id ?? (await getDepotDefautId());
  const payload = {
    date_retour: input.date_retour ?? new Date().toISOString().slice(0, 10),
    client_id: input.client_id,
    etablissement: input.etablissement ?? null,
    representant_nom: input.representant_nom ?? null,
    telephone: input.telephone ?? null,
    ville: input.ville ?? null,
    adresse: input.adresse ?? null,
    depot_id,
    observations: input.observations ?? null,
    notes: input.notes ?? null,
    facture_id: input.facture_id ?? null,
    livraison_id: input.livraison_id ?? null,
    lignes: input.lignes.map((l) => ({
      produit_id: l.produit_id,
      reference_produit: l.reference_produit ?? null,
      designation: l.designation,
      quantite: l.quantite,
      motif: l.motif ?? null,
    })),
  };

  const { data, error } = await (
    supabase as unknown as {
      rpc: (
        name: string,
        args: { _payload: unknown },
      ) => Promise<{ data: unknown; error: Error | null }>;
    }
  ).rpc("creer_retour", { _payload: payload });

  if (error) throw error;
  return data as Retour;
}

export async function annulerRetour(id: string): Promise<void> {
  await assertPermission("retours.annuler");
  const { error } = await (
    supabase as unknown as {
      rpc: (name: string, args: { _retour_id: string }) => Promise<{ error: Error | null }>;
    }
  ).rpc("annuler_retour", { _retour_id: id });
  if (error) throw error;
}

// ============================================================================
// Lot 1 — Retour rattaché à une facture
// ============================================================================

export type LigneRetournable = {
  produit_id: string;
  reference_produit: string | null;
  designation: string;
  qte_vendue: number;
  qte_deja_retournee: number;
  qte_disponible: number;
  prix_unitaire: number;
  remise_pct: number;
  total_ligne: number;
};

export async function getLignesRetournables(factureId: string): Promise<LigneRetournable[]> {
  const { data, error } = await (
    supabase as unknown as {
      rpc: (
        name: string,
        args: { _facture_id: string },
      ) => Promise<{ data: unknown; error: Error | null }>;
    }
  ).rpc("get_lignes_retournables", { _facture_id: factureId });
  if (error) throw error;
  return (data ?? []) as LigneRetournable[];
}

export type FactureRetourOption = {
  facture_id: string;
  reference: string;
  date_facture: string;
  montant_total: number;
  statut: string;
};

export async function searchFacturesClient(
  clientId: string,
  q?: string,
): Promise<FactureRetourOption[]> {
  let query = supabase
    .from("factures")
    .select("facture_id,reference,date_facture,montant_total,statut")
    .eq("client_id", clientId)
    .not("commande_id", "is", null)
    .neq("statut", "annulee")
    .order("date_facture", { ascending: false })
    .limit(20);
  if (q && q.trim()) query = query.ilike("reference", `%${q.trim()}%`);
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as FactureRetourOption[];
}
