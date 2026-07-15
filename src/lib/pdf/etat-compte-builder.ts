// Construit les lignes d'un état de compte client (situations + mouvements)
// à partir des factures, paiements et avoirs (bons_retour) et appelle le
// générateur PDF V10 avec regroupement par exercice et sous-totaux.
import { supabase } from "@/integrations/supabase/client";
import { generateEtatCompteClientPDF, type EtatCompteLigne } from "@/lib/pdf/fabsTemplates";
import { computeSoldeClient } from "@/lib/pdf/etat-compte-solde";

export type EtatCompteClientArgs = {
  clientId: string;
  clientNom: string;
  clientTel?: string | null;
  representant?: string | null;
  /** Année min incluse (situations = mouvements antérieurs cumulés). */
  exerciceMin?: number;
  /** Exercice à afficher : filtre les mouvements sur [date_debut, date_fin] et injecte le report à-nouveau. */
  exerciceId?: string | null;
};

export async function buildEtatCompteClientPDF(args: EtatCompteClientArgs): Promise<Blob> {
  const [{ data: factures }, { data: paiements }, { data: avoirs }] = await Promise.all([
    supabase
      .from("factures")
      .select("reference, date_facture, montant_total")
      .eq("client_id", args.clientId)
      .order("date_facture", { ascending: true }),
    supabase
      .from("paiements")
      .select("reference, date_paiement, montant, statut, facture_id, factures!inner(client_id)")
      .eq("factures.client_id", args.clientId)
      .order("date_paiement", { ascending: true }),
    supabase
      .from("bons_retour")
      .select("reference, date_retour, montant, statut")
      .eq("client_id", args.clientId)
      .order("date_retour", { ascending: true }),
  ]);

  // Bornes de la période
  let dateDebut: string | null = null;
  let dateFin: string | null = null;
  let soldeOuvertureRow = 0;
  if (args.exerciceId) {
    const [{ data: ex }, { data: ouv }] = await Promise.all([
      supabase
        .from("exercices")
        .select("date_debut, date_fin")
        .eq("exercice_id", args.exerciceId)
        .maybeSingle(),
      supabase
        .from("soldes_ouverture_clients")
        .select("montant")
        .eq("client_id", args.clientId)
        .eq("exercice_id", args.exerciceId)
        .maybeSingle(),
    ]);
    if (ex) {
      dateDebut = ex.date_debut as string;
      dateFin = ex.date_fin as string;
    }
    soldeOuvertureRow = ouv ? Number(ouv.montant) : 0;
  } else if (args.exerciceMin) {
    dateDebut = `${args.exerciceMin}-01-01`;
  }

  const paiementsFlat = (paiements ?? []).map((p) => ({
    reference: p.reference,
    date_paiement: p.date_paiement,
    montant: p.montant,
    statut: p.statut ?? null,
  }));
  const res = computeSoldeClient({
    clientId: args.clientId,
    dateDebut,
    dateFin,
    soldeOuvertureRow,
    factures: factures ?? [],
    paiements: paiementsFlat,
    avoirs: avoirs ?? [],
  });
  const lignesFiltrees: EtatCompteLigne[] = res.lignes;
  const soldeOuverture = res.soldeOuverture;

  const yyyy = new Date().getFullYear();
  const ref = `EC|${yyyy}|${args.clientNom.replace(/\s+/g, "_").toUpperCase().slice(0, 20)}`;

  return generateEtatCompteClientPDF({
    reference: ref,
    clientNom: args.clientNom,
    clientTel: args.clientTel,
    representant: args.representant,
    soldeOuverture,
    lignes: lignesFiltrees,
    note: res.emptyExplanation,
  });
}
