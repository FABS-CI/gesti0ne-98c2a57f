import { supabase } from "@/integrations/supabase/client";
import { getDepotDefautId } from "@/lib/parametres-api";
import { assertPermission } from "@/lib/rbac-api";

export const STATUTS_SPECIMEN = [
  { value: "enregistre", label: "Enregistré", color: "#10B981" },
  { value: "annule", label: "Annulé", color: "#EF4444" },
] as const;

export const STATUT_SPECIMEN_LABEL: Record<string, { label: string; color: string }> =
  Object.fromEntries(STATUTS_SPECIMEN.map((s) => [s.value, { label: s.label, color: s.color }]));

export type Specimen = {
  specimen_id: string;
  numero: string;
  date_envoi: string;
  client_id: string | null;
  etablissement: string;
  representant_nom: string | null;
  telephone: string | null;
  ville: string | null;
  adresse: string | null;
  donneur_nom: string;
  motif: string | null;
  observations: string | null;
  statut: string;
  gestionnaire_id: string | null;
  gestionnaire_nom: string | null;
  total_quantite: number;
  nb_produits: number;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

export type SpecimenLigne = {
  ligne_id: string;
  specimen_id: string;
  produit_id: string;
  reference_produit: string | null;
  designation: string;
  quantite: number;
  created_at: string;
};

export type SpecimenWithLignes = Specimen & { lignes: SpecimenLigne[] };

export type SpecimenLigneInput = {
  produit_id: string;
  reference_produit?: string | null;
  designation: string;
  quantite: number;
};

export type SpecimenInput = {
  date_envoi?: string;
  client_id: string;
  etablissement?: string | null;
  representant_nom?: string | null;
  telephone?: string | null;
  ville?: string | null;
  adresse?: string | null;
  donneur_nom: string;
  motif?: string | null;
  observations?: string | null;
  depot_id?: string | null;
  lignes: SpecimenLigneInput[];
};

export type ListSpecimensParams = {
  q?: string;
  statut?: string;
  client_id?: string;
  ville?: string;
  date_from?: string;
  date_to?: string;
};

export async function listSpecimens(params: ListSpecimensParams = {}): Promise<Specimen[]> {
  let query = supabase
    .from("specimens")
    .select("*")
    .order("date_envoi", { ascending: false })
    .order("created_at", { ascending: false });

  if (params.statut && params.statut !== "all") query = query.eq("statut", params.statut);
  if (params.client_id) query = query.eq("client_id", params.client_id);
  if (params.ville) query = query.ilike("ville", `%${params.ville}%`);
  if (params.date_from) query = query.gte("date_envoi", params.date_from);
  if (params.date_to) query = query.lte("date_envoi", params.date_to);
  if (params.q && params.q.trim()) {
    const t = `%${params.q.trim()}%`;
    query = query.or(
      `numero.ilike.${t},etablissement.ilike.${t},representant_nom.ilike.${t},motif.ilike.${t},donneur_nom.ilike.${t}`,
    );
  }
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as Specimen[];
}

export async function getSpecimen(id: string): Promise<SpecimenWithLignes> {
  const { data, error } = await supabase
    .from("specimens")
    .select("*")
    .eq("specimen_id", id)
    .single();
  if (error) throw error;
  const { data: lignes, error: errL } = await supabase
    .from("specimen_lignes")
    .select("*")
    .eq("specimen_id", id)
    .order("created_at", { ascending: true });
  if (errL) throw errL;
  return { ...(data as Specimen), lignes: (lignes ?? []) as SpecimenLigne[] };
}

export async function creerSpecimen(input: SpecimenInput): Promise<Specimen> {
  await assertPermission("specimens.creer");
  const depot_id = input.depot_id ?? (await getDepotDefautId());
  const payload = {
    date_envoi: input.date_envoi ?? new Date().toISOString().slice(0, 10),
    client_id: input.client_id,
    depot_id,
    etablissement: input.etablissement ?? null,
    representant_nom: input.representant_nom ?? null,
    telephone: input.telephone ?? null,
    ville: input.ville ?? null,
    adresse: input.adresse ?? null,
    donneur_nom: input.donneur_nom,
    motif: input.motif ?? null,
    observations: input.observations ?? null,
    lignes: input.lignes.map((l) => ({
      produit_id: l.produit_id,
      reference_produit: l.reference_produit ?? null,
      designation: l.designation,
      quantite: l.quantite,
    })),
  };

  const { data, error } = await (
    supabase as unknown as {
      rpc: (
        name: string,
        args: { _payload: unknown },
      ) => Promise<{ data: unknown; error: Error | null }>;
    }
  ).rpc("creer_specimen", { _payload: payload });

  if (error) {
    console.error("[specimens-api] creerSpecimen error", error);
    throw error;
  }
  return data as Specimen;
}

export async function annulerSpecimen(id: string): Promise<void> {
  await assertPermission("specimens.annuler");
  const { error } = await (
    supabase as unknown as {
      rpc: (name: string, args: { _specimen_id: string }) => Promise<{ error: Error | null }>;
    }
  ).rpc("annuler_specimen", { _specimen_id: id });
  if (error) throw error;
}

export type SpecimenStats = {
  total_remises: number;
  total_quantite: number;
  par_etablissement: { nom: string; total: number }[];
  par_gestionnaire: { nom: string; total: number }[];
  top_produits: { designation: string; quantite: number }[];
};

export async function statsSpecimens(): Promise<SpecimenStats> {
  const { data, error } = await supabase
    .from("specimens")
    .select("total_quantite, etablissement, gestionnaire_nom")
    .eq("statut", "enregistre");
  if (error) throw error;
  const rows = (data ?? []) as Array<{
    total_quantite: number;
    etablissement: string | null;
    gestionnaire_nom: string | null;
  }>;
  const par = (key: "etablissement" | "gestionnaire_nom") => {
    const m = new Map<string, number>();
    for (const r of rows) {
      const k = (r[key] ?? "—").trim() || "—";
      m.set(k, (m.get(k) ?? 0) + (r.total_quantite || 0));
    }
    return Array.from(m.entries())
      .map(([nom, total]) => ({ nom, total }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 5);
  };
  const { data: lignes } = await supabase
    .from("specimen_lignes")
    .select("designation, quantite, specimens!inner(statut)")
    .eq("specimens.statut", "enregistre");
  const topMap = new Map<string, number>();
  for (const l of (lignes ?? []) as Array<{ designation: string; quantite: number }>) {
    topMap.set(l.designation, (topMap.get(l.designation) ?? 0) + (l.quantite || 0));
  }
  return {
    total_remises: rows.length,
    total_quantite: rows.reduce((s, r) => s + (r.total_quantite || 0), 0),
    par_etablissement: par("etablissement"),
    par_gestionnaire: par("gestionnaire_nom"),
    top_produits: Array.from(topMap.entries())
      .map(([designation, quantite]) => ({ designation, quantite }))
      .sort((a, b) => b.quantite - a.quantite)
      .slice(0, 5),
  };
}
