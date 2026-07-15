import { supabase } from "@/integrations/supabase/client";

// -------- Types -----------------------------------------------------------

export type Transporteur = {
  transporteur_id: string;
  nom: string;
  telephone: string | null;
  contact: string | null;
  type: string | null;
  actif: boolean;
};

export type Gare = {
  gare_id: string;
  nom: string;
  ville: string | null;
  code: string | null;
  actif: boolean;
  transporteur_id: string | null;
};

export type LivreurLite = {
  livreur_id: string;
  nom: string;
  telephone: string | null;
  actif: boolean;
};

export type LivraisonPrefill = {
  source: "colisage" | "expedition";
  bl_id: string | null;
  expedition_id: string | null;
  client: {
    client_id: string;
    nom: string;
    telephone: string | null;
    email: string | null;
    adresse: string | null;
    ville: string | null;
    commune: string | null;
  } | null;
  colis: {
    nb_colis: number;
    nb_cartons: number;
    poids_total: number;
    volume_total: number;
    valeur_total: number;
  };
  expedition: {
    reference: string;
    date_depart: string | null;
    date_arrivee_prevue: string | null;
    transporteur_libre: string | null;
  } | null;
  destination: {
    adresse: string | null;
    ville: string | null;
    commune: string | null;
  };
};

// -------- Référentiels ----------------------------------------------------

const SEARCH_LIMIT = 20;

export async function listTransporteurs(): Promise<Transporteur[]> {
  const { data, error } = await supabase
    .from("transporteurs")
    .select("transporteur_id, nom, telephone, contact, type, actif")
    .eq("actif", true)
    .order("nom")
    .limit(SEARCH_LIMIT);
  if (error) throw error;
  return (data ?? []) as Transporteur[];
}

export async function searchTransporteurs(term: string): Promise<Transporteur[]> {
  let q = supabase
    .from("transporteurs")
    .select("transporteur_id, nom, telephone, contact, type, actif")
    .eq("actif", true)
    .order("nom")
    .limit(SEARCH_LIMIT);
  if (term.trim()) q = q.ilike("nom", `%${term.trim()}%`);
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []) as Transporteur[];
}

export async function getTransporteurById(id: string): Promise<Transporteur | null> {
  const { data, error } = await supabase
    .from("transporteurs")
    .select("transporteur_id, nom, telephone, contact, type, actif")
    .eq("transporteur_id", id)
    .maybeSingle();
  if (error) throw error;
  return (data as Transporteur | null) ?? null;
}

export async function listGares(): Promise<Gare[]> {
  const { data, error } = await supabase
    .from("gares")
    .select("gare_id, nom, ville, code, actif, transporteur_id")
    .eq("actif", true)
    .order("nom")
    .limit(SEARCH_LIMIT);
  if (error) throw error;
  return (data ?? []) as Gare[];
}

export async function searchGares(term: string, transporteurId?: string | null): Promise<Gare[]> {
  let q = supabase
    .from("gares")
    .select("gare_id, nom, ville, code, actif, transporteur_id")
    .eq("actif", true)
    .order("nom")
    .limit(SEARCH_LIMIT);
  if (term.trim()) q = q.ilike("nom", `%${term.trim()}%`);
  if (transporteurId) {
    // gares dédiées à cette compagnie + gares génériques (sans transporteur)
    q = q.or(`transporteur_id.eq.${transporteurId},transporteur_id.is.null`);
  }
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []) as Gare[];
}

export async function getGareById(id: string): Promise<Gare | null> {
  const { data, error } = await supabase
    .from("gares")
    .select("gare_id, nom, ville, code, actif, transporteur_id")
    .eq("gare_id", id)
    .maybeSingle();
  if (error) throw error;
  return (data as Gare | null) ?? null;
}

export async function listLivreursActifs(): Promise<LivreurLite[]> {
  const { data, error } = await supabase
    .from("livreurs")
    .select("livreur_id, nom, telephone, actif")
    .eq("actif", true)
    .order("nom")
    .limit(SEARCH_LIMIT);
  if (error) throw error;
  return (data ?? []) as LivreurLite[];
}

export async function searchLivreurs(term: string): Promise<LivreurLite[]> {
  let q = supabase
    .from("livreurs")
    .select("livreur_id, nom, telephone, actif")
    .eq("actif", true)
    .order("nom")
    .limit(SEARCH_LIMIT);
  if (term.trim()) q = q.ilike("nom", `%${term.trim()}%`);
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []) as LivreurLite[];
}

export async function getLivreurById(id: string): Promise<LivreurLite | null> {
  const { data, error } = await supabase
    .from("livreurs")
    .select("livreur_id, nom, telephone, actif")
    .eq("livreur_id", id)
    .maybeSingle();
  if (error) throw error;
  return (data as LivreurLite | null) ?? null;
}

// -------- Préremplissage ---------------------------------------------------

async function getColisAgg(blId: string) {
  const { data, error } = await supabase
    .from("colis")
    .select("colis_id, commande_id, poids, nb_cartons")
    .eq("bl_id", blId);
  if (error) throw error;
  const rows = (data ?? []) as Array<{
    commande_id: string | null;
    poids: number | null;
    nb_cartons: number | null;
  }>;
  // Règle métier : 1 commande = 1 colis (peut contenir N cartons).
  // Chaque ligne de la table `colis` = 1 carton physique.
  const commandeIds = new Set(rows.map((r) => r.commande_id).filter(Boolean));
  return {
    nb_colis: commandeIds.size || (rows.length > 0 ? 1 : 0),
    nb_cartons: rows.length,
    poids_total: rows.reduce((s, r) => s + Number(r.poids ?? 0), 0),
    volume_total: 0,
    valeur_total: 0,
  };
}

async function getClientLite(clientId: string) {
  const { data, error } = await supabase
    .from("clients")
    .select("client_id, nom, telephone, email, adresse, ville, commune")
    .eq("client_id", clientId)
    .maybeSingle();
  if (error) throw error;
  return data as LivraisonPrefill["client"];
}

export async function getPrefillFromColisage(blId: string): Promise<LivraisonPrefill> {
  const { data: bl, error } = await supabase
    .from("bons_livraison")
    .select("bl_id, client_id, adresse_livraison, transporteur")
    .eq("bl_id", blId)
    .maybeSingle();
  if (error) throw error;
  if (!bl) throw new Error("Bon de livraison introuvable");
  const [colisAgg, client, { data: exp }] = await Promise.all([
    getColisAgg(blId),
    bl.client_id ? getClientLite(bl.client_id) : Promise.resolve(null),
    supabase
      .from("expeditions")
      .select("expedition_id, reference, date_depart, date_arrivee_prevue, transporteur")
      .eq("bl_id", blId)
      .maybeSingle(),
  ]);
  return {
    source: "colisage",
    bl_id: bl.bl_id,
    expedition_id: exp?.expedition_id ?? null,
    client,
    colis: colisAgg,
    expedition: exp
      ? {
          reference: exp.reference,
          date_depart: exp.date_depart,
          date_arrivee_prevue: exp.date_arrivee_prevue,
          transporteur_libre: exp.transporteur,
        }
      : null,
    destination: {
      adresse: bl.adresse_livraison ?? client?.adresse ?? null,
      ville: client?.ville ?? null,
      commune: client?.commune ?? null,
    },
  };
}

export async function getPrefillFromExpedition(expeditionId: string): Promise<LivraisonPrefill> {
  const { data: exp, error } = await supabase
    .from("expeditions")
    .select("expedition_id, reference, date_depart, date_arrivee_prevue, transporteur, bl_id")
    .eq("expedition_id", expeditionId)
    .maybeSingle();
  if (error) throw error;
  if (!exp) throw new Error("Expédition introuvable");
  if (exp.bl_id) {
    const base = await getPrefillFromColisage(exp.bl_id);
    return { ...base, source: "expedition", expedition_id: exp.expedition_id };
  }
  return {
    source: "expedition",
    bl_id: null,
    expedition_id: exp.expedition_id,
    client: null,
    colis: { nb_colis: 0, nb_cartons: 0, poids_total: 0, volume_total: 0, valeur_total: 0 },
    expedition: {
      reference: exp.reference,
      date_depart: exp.date_depart,
      date_arrivee_prevue: exp.date_arrivee_prevue,
      transporteur_libre: exp.transporteur,
    },
    destination: { adresse: null, ville: null, commune: null },
  };
}

// -------- Création --------------------------------------------------------

export type CreateLivraisonInput = {
  bl_id: string | null;
  expedition_id: string | null;
  client_id: string;
  transporteur_id: string;
  livreur_id: string;
  gare_depart_id: string | null;
  gare_arrivee_id: string | null;
  date_livraison: string;
  adresse: string;
  ville: string | null;
  commune: string | null;
  telephone_dest: string | null;
  contact_dest: string | null;
  notes: string | null;
  client_nom: string;
  transporteur_nom: string;
};

export async function createLivraison(input: CreateLivraisonInput) {
  // Validation stricte : chaque FK doit exister en base
  const checks: Array<PromiseLike<{ ok: boolean; label: string }>> = [
    supabase
      .from("transporteurs")
      .select("transporteur_id", { head: true, count: "exact" })
      .eq("transporteur_id", input.transporteur_id)
      .then((r) => ({
        ok: (r.count ?? 0) > 0,
        label: "Transporteur",
      })),
    supabase
      .from("livreurs")
      .select("livreur_id", { head: true, count: "exact" })
      .eq("livreur_id", input.livreur_id)
      .then((r) => ({ ok: (r.count ?? 0) > 0, label: "Livreur" })),
  ];
  if (input.gare_depart_id) {
    checks.push(
      supabase
        .from("gares")
        .select("gare_id", { head: true, count: "exact" })
        .eq("gare_id", input.gare_depart_id)
        .then((r) => ({
          ok: (r.count ?? 0) > 0,
          label: "Gare de départ",
        })),
    );
  }
  if (input.gare_arrivee_id) {
    checks.push(
      supabase
        .from("gares")
        .select("gare_id", { head: true, count: "exact" })
        .eq("gare_id", input.gare_arrivee_id)
        .then((r) => ({
          ok: (r.count ?? 0) > 0,
          label: "Gare d'arrivée",
        })),
    );
  }
  const results = await Promise.all(checks);
  const missing = results.filter((r) => !r.ok).map((r) => r.label);
  if (missing.length > 0) {
    throw new Error(
      `Valeur inexistante en base : ${missing.join(", ")}. Sélectionne uniquement des entrées de la liste.`,
    );
  }

  const { data, error } = await supabase
    .from("livraisons")
    .insert({
      bl_id: input.bl_id,
      expedition_id: input.expedition_id,
      client_id: input.client_id,
      transporteur_id: input.transporteur_id,
      livreur_id: input.livreur_id,
      gare_depart_id: input.gare_depart_id,
      gare_arrivee_id: input.gare_arrivee_id,
      date_livraison: input.date_livraison,
      adresse: input.adresse,
      ville: input.ville,
      commune: input.commune,
      telephone_dest: input.telephone_dest,
      contact_dest: input.contact_dest,
      notes: input.notes,
      client_nom: input.client_nom,
      transporteur: input.transporteur_nom,
      statut: "planifiee",
      figee: false,
    })
    .select("livraison_id")
    .single();
  if (error) throw error;
  return data as { livraison_id: string };
}

// -------- Autocomplete sources -------------------------------------------

export async function searchColisageBls(q: string) {
  let query = supabase
    .from("bons_livraison")
    .select("bl_id, reference, date_emission, client_id")
    .neq("statut", "annule")
    .order("date_emission", { ascending: false })
    .limit(20);
  if (q) query = query.ilike("reference", `%${q}%`);
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as Array<{
    bl_id: string;
    reference: string;
    date_emission: string;
    client_id: string | null;
  }>;
}

export async function searchExpeditions(q: string) {
  let query = supabase
    .from("expeditions")
    .select("expedition_id, reference, date_depart, bl_id")
    .order("created_at", { ascending: false })
    .limit(20);
  if (q) query = query.ilike("reference", `%${q}%`);
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as Array<{
    expedition_id: string;
    reference: string;
    date_depart: string | null;
    bl_id: string | null;
  }>;
}
