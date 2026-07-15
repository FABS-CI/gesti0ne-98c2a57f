import { supabase } from "@/integrations/supabase/client";
import { callRpc } from "@/lib/rpc";
import { getDepotDefautId } from "@/lib/parametres-api";
import type { Json } from "@/integrations/supabase/types";

export const TYPES_INCIDENT = [
  { value: "document_endommage", label: "Document endommagé" },
  { value: "livre_dechire", label: "Livre déchiré" },
  { value: "produit_mouille", label: "Produit mouillé" },
  { value: "produit_obsolete", label: "Produit obsolète" },
  { value: "erreur_impression", label: "Erreur d'impression" },
  { value: "defaut_fabrication", label: "Défaut de fabrication" },
  { value: "produit_perdu", label: "Produit perdu" },
  { value: "produit_vole", label: "Produit volé" },
  { value: "produit_detruit", label: "Produit détruit" },
  { value: "autre", label: "Autre" },
] as const;

export const TYPE_INCIDENT_LABEL: Record<string, string> = Object.fromEntries(
  TYPES_INCIDENT.map((t) => [t.value, t.label]),
);

export const STATUTS_INCIDENT = [
  { value: "declare", label: "Déclaré", color: "#F97316" },
  { value: "valide", label: "Validé", color: "#10B981" },
  { value: "annule", label: "Annulé", color: "#EF4444" },
  // legacy
  { value: "ouvert", label: "Ouvert", color: "#EF4444" },
  { value: "en_cours", label: "En cours", color: "#F97316" },
  { value: "resolu", label: "Résolu", color: "#10B981" },
] as const;

export const STATUT_INCIDENT_LABEL: Record<string, { label: string; color: string }> =
  Object.fromEntries(STATUTS_INCIDENT.map((s) => [s.value, { label: s.label, color: s.color }]));

export type Incident = {
  incident_id: string;
  reference: string;
  numero: string | null;
  type_incident: string;
  gravite: string;
  description: string | null;
  date_incident: string;
  statut: string;
  motif: string | null;
  observations: string | null;
  depot_id: string | null;
  responsable_id: string | null;
  responsable_nom: string | null;
  total_quantite: number;
  nb_produits: number;
  created_at: string;
  updated_at: string;
  depots?: { nom: string; code: string } | null;
};

export type IncidentLigne = {
  ligne_id: string;
  incident_id: string;
  produit_id: string;
  reference_produit: string | null;
  designation: string;
  quantite: number;
  created_at: string;
};

export type IncidentLigneInput = {
  produit_id: string;
  reference_produit?: string | null;
  designation: string;
  quantite: number;
};

export type IncidentInput = {
  date_incident: string;
  type_incident: string;
  depot_id?: string | null;
  motif?: string | null;
  observations?: string | null;
  lignes: IncidentLigneInput[];
};

export async function listIncidents(filters?: {
  q?: string;
  statut?: string;
  type?: string;
  depot_id?: string;
}) {
  let q = supabase
    .from("incidents")
    .select("*, depots(nom, code)")
    .order("date_incident", { ascending: false });
  if (filters?.q)
    q = q.or(
      `numero.ilike.%${filters.q}%,reference.ilike.%${filters.q}%,motif.ilike.%${filters.q}%`,
    );
  if (filters?.statut) q = q.eq("statut", filters.statut);
  if (filters?.type) q = q.eq("type_incident", filters.type);
  if (filters?.depot_id) q = q.eq("depot_id", filters.depot_id);
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []) as unknown as Incident[];
}

export async function getIncident(id: string) {
  const { data, error } = await supabase
    .from("incidents")
    .select("*, depots(nom, code)")
    .eq("incident_id", id)
    .single();
  if (error) throw error;
  return data as unknown as Incident;
}

export async function getIncidentLignes(id: string) {
  const { data, error } = await supabase
    .from("incident_lignes")
    .select("*")
    .eq("incident_id", id)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as IncidentLigne[];
}

export async function creerIncident(input: IncidentInput) {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("incidents.creer");
  const depot_id = input.depot_id ?? (await getDepotDefautId());
  const { data, error } = await callRpc("creer_incident_stock", {
    _payload: { ...input, depot_id } as unknown as Json,
  });
  if (error) throw error;
  return data as unknown as Incident;
}

export async function annulerIncident(id: string) {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("incidents.annuler");
  const { error } = await callRpc("annuler_incident", { _incident_id: id });
  if (error) throw error;
}
