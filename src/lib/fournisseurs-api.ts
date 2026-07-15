import { supabase } from "@/integrations/supabase/client";

export type Fournisseur = {
  fournisseur_id: string;
  raison_sociale: string;
  contact: string | null;
  email: string | null;
  telephone: string | null;
  adresse: string | null;
  ville: string | null;
  actif: boolean;
  created_at: string;
  updated_at: string;
};

export type FournisseurInput = {
  raison_sociale: string;
  contact?: string | null;
  email?: string | null;
  telephone?: string | null;
  adresse?: string | null;
  ville?: string | null;
  actif: boolean;
};

export async function listFournisseurs(q?: string) {
  let query = supabase.from("fournisseurs").select("*");
  if (q) query = query.or(`raison_sociale.ilike.%${q}%,contact.ilike.%${q}%,ville.ilike.%${q}%`);
  query = query.order("raison_sociale", { ascending: true });
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as Fournisseur[];
}

export async function createFournisseur(input: FournisseurInput) {
  const { data, error } = await supabase.from("fournisseurs").insert(input).select().single();
  if (error) throw error;
  return data as Fournisseur;
}

export async function updateFournisseur(id: string, input: FournisseurInput) {
  const { data, error } = await supabase
    .from("fournisseurs")
    .update(input)
    .eq("fournisseur_id", id)
    .select()
    .single();
  if (error) throw error;
  return data as Fournisseur;
}

export async function deleteFournisseur(id: string, motif?: string | null) {
  const { error } = await supabase.rpc("supprimer_fournisseur" as never, {
    _fournisseur_id: id,
    _motif: motif ?? "",
  } as never);
  if (error) throw error;
}

export async function getFournisseur(id: string) {
  const { data, error } = await supabase
    .from("fournisseurs")
    .select("*")
    .eq("fournisseur_id", id)
    .maybeSingle();
  if (error) throw error;
  return data as Fournisseur | null;
}

export async function getFournisseurAchats(fournisseurId: string) {
  const { data, error } = await supabase
    .from("achats")
    .select("*")
    .eq("fournisseur_id", fournisseurId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}
