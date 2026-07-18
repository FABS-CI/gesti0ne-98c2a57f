// Construit l'état de compte client enrichi : historique complet + résumé.
// - Mouvements chronologiques (factures / paiements / avoirs) via computeSoldeClient
// - Détail des commandes (statut + quantités livrées)
// - Détail des paiements (mode + numéro de reçu)
// - Vieillissement des créances (buckets 0-30 / 31-60 / 61-90 / 90+)
import { supabase } from "@/integrations/supabase/client";
import {
  generateEtatCompteClientPDF,
  type EtatCompteCommandeRow,
  type EtatCompteLigne,
  type EtatComptePaiementRow,
  type EtatCompteAgeing,
} from "@/lib/pdf/fabsTemplates";
import { computeSoldeClient } from "@/lib/pdf/etat-compte-solde";

export type EtatCompteClientArgs = {
  clientId: string;
  clientNom: string;
  clientTel?: string | null;
  representant?: string | null;
  exerciceMin?: number;
  exerciceId?: string | null;
};

type CommandeLigneAgg = { quantite: number | null; quantite_livree: number | null };
type CommandeRow = {
  commande_id: string;
  reference: string | null;
  date_commande: string;
  montant_total: number | null;
  statut: string | null;
  commande_lignes?: CommandeLigneAgg[] | null;
};

type FactureCompteRow = {
  facture_id: string;
  reference: string | null;
  date_facture: string;
  date_echeance: string | null;
  montant_total: number | null;
  montant_paye: number | null;
  statut: string | null;
};

type RetourCompteRow = {
  reference: string | null;
  date_retour: string;
  montant: number | null;
  statut: string | null;
  facture_id: string | null;
};

export async function buildEtatCompteClientPDF(args: EtatCompteClientArgs): Promise<Blob> {
  // --- Client complet
  const { data: cli } = await supabase
    .from("clients")
    .select("reference, nom, adresse, ville, telephone, email, representant")
    .eq("client_id", args.clientId)
    .maybeSingle();

  const clientBlock = {
    code: cli?.reference ?? null,
    nom: cli?.nom ?? args.clientNom,
    adresse: [cli?.adresse, cli?.ville].filter(Boolean).join(" — ") || null,
    telephone: cli?.telephone ?? args.clientTel ?? null,
    email: cli?.email ?? null,
    representant: cli?.representant ?? args.representant ?? null,
  };

  // --- Bornes période + solde d'ouverture
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

  // --- Charge mouvements financiers
  const [{ data: factures }, { data: paiements }, { data: avoirs }, { data: commandes }] =
    await Promise.all([
      supabase
        .from("factures")
        .select("facture_id, reference, date_facture, date_echeance, montant_total, montant_paye, statut")
        .eq("client_id", args.clientId)
        .order("date_facture", { ascending: true }),
      supabase
        .from("paiements")
        .select(
          "reference, date_paiement, montant, statut, mode_paiement, reference_paiement, factures!inner(client_id)",
        )
        .eq("factures.client_id", args.clientId)
        .order("date_paiement", { ascending: true }),
      supabase
        .from("retours")
        .select("reference, date_retour, montant, statut, facture_id")
        .eq("client_id", args.clientId)
        .neq("statut", "annule")
        .order("date_retour", { ascending: true }),
      supabase
        .from("commandes")
        .select(
          "commande_id, reference, date_commande, montant_total, statut, commande_lignes(quantite, quantite_livree)",
        )
        .eq("client_id", args.clientId)
        .order("date_commande", { ascending: true }),
    ]);

  const paiementsFlat = (paiements ?? []).map((p) => ({
    reference: p.reference,
    date_paiement: p.date_paiement,
    montant: p.montant,
    statut: p.statut ?? null,
  }));

  const facturesCompte = (factures ?? []) as FactureCompteRow[];
  const retoursCompte = (avoirs ?? []) as RetourCompteRow[];
  const retoursParFacture = new Map<string, number>();
  const factureRefParRetour = new Map<string, string>();
  const factureRefParId = new Map(
    facturesCompte.map((f) => [f.facture_id, f.reference ?? ""]),
  );
  for (const retour of retoursCompte) {
    if (retour.facture_id) {
      retoursParFacture.set(
        retour.facture_id,
        (retoursParFacture.get(retour.facture_id) ?? 0) + Number(retour.montant ?? 0),
      );
      factureRefParRetour.set(
        retour.reference ?? "",
        factureRefParId.get(retour.facture_id) ?? "",
      );
    }
  }

  // Le montant stocké sur la facture est déjà diminué des retours. Pour un relevé
  // comptable lisible, on reconstitue la facture d'origine puis on affiche chaque
  // retour séparément au crédit, sans compter l'avoir deux fois.
  const facturesReleve = facturesCompte.map((f) => ({
    ...f,
    montant_total: Number(f.montant_total ?? 0) + (retoursParFacture.get(f.facture_id) ?? 0),
  }));
  const avoirsReleve = retoursCompte.map((r) => ({
    ...r,
    statut: "valide",
  }));

  const res = computeSoldeClient({
    clientId: args.clientId,
    dateDebut,
    dateFin,
    soldeOuvertureRow,
    factures: facturesReleve,
    paiements: paiementsFlat,
    avoirs: avoirsReleve,
  });

  // --- Enrichit les lignes avec un libellé humain
  const lignes: EtatCompteLigne[] = res.lignes.map((l) => ({
    ...l,
    factureReference: l.type === "Avoir" ? factureRefParRetour.get(l.reference) : undefined,
    libelle:
      l.type === "Facture"
        ? `Facture ${l.reference}`
        : l.type === "Paiement"
          ? `Règlement ${l.reference}`
          : l.type === "Avoir"
            ? `Avoir / retour ${l.reference}`
            : "",
  }));

  // --- Détail commandes (période)
  const inPeriod = (iso: string | null | undefined) => {
    if (!iso) return false;
    const t = new Date(iso).getTime();
    if (isNaN(t)) return false;
    if (dateDebut && t < new Date(dateDebut).getTime()) return false;
    if (dateFin && t > new Date(dateFin).getTime()) return false;
    return true;
  };
  const commandesRows: EtatCompteCommandeRow[] = ((commandes ?? []) as CommandeRow[])
    .filter((c) => (dateDebut || dateFin ? inPeriod(c.date_commande) : true))
    .map((c) => {
      const lignesCmd = c.commande_lignes ?? [];
      const qteCommandee = lignesCmd.reduce((s, l) => s + Number(l.quantite ?? 0), 0);
      const qteLivree = lignesCmd.reduce((s, l) => s + Number(l.quantite_livree ?? 0), 0);
      const qteRestante = Math.max(0, qteCommandee - qteLivree);
      let statut = c.statut ?? "";
      if (qteCommandee > 0) {
        if (qteLivree === 0) statut = statut || "en_attente";
        else if (qteLivree < qteCommandee) statut = "partiellement_livree";
        else statut = "livree";
      }
      return {
        reference: c.reference ?? "",
        date: c.date_commande,
        montant: Number(c.montant_total ?? 0),
        statut,
        qteCommandee,
        qteLivree,
        qteRestante,
      };
    });

  // --- Détail paiements (période, valides)
  const paiementsRows: EtatComptePaiementRow[] = (paiements ?? [])
    .filter((p) => (p.statut ? p.statut === "valide" : true))
    .filter((p) => (dateDebut || dateFin ? inPeriod(p.date_paiement) : true))
    .map((p) => ({
      date: p.date_paiement,
      reference: p.reference ?? "",
      mode: p.mode_paiement ?? "",
      numeroRecu: p.reference_paiement ?? null,
      montant: Number(p.montant ?? 0),
    }));

  // --- Vieillissement (factures non entièrement payées, dans la période)
  const today = new Date();
  const ageing: EtatCompteAgeing = { nonEchu: 0, j0_30: 0, j31_60: 0, j61_90: 0, j90plus: 0 };
  for (const f of facturesReleve) {
    const reste = Number(f.montant_total ?? 0) - Number(f.montant_paye ?? 0);
    if (reste <= 0) continue;
    const ech = f.date_echeance ? new Date(f.date_echeance as string) : null;
    if (!ech || isNaN(ech.getTime())) {
      ageing.j0_30 += reste;
      continue;
    }
    const diffJ = Math.floor((today.getTime() - ech.getTime()) / (1000 * 60 * 60 * 24));
    if (diffJ < 0) ageing.nonEchu += reste;
    else if (diffJ <= 30) ageing.j0_30 += reste;
    else if (diffJ <= 60) ageing.j31_60 += reste;
    else if (diffJ <= 90) ageing.j61_90 += reste;
    else ageing.j90plus += reste;
  }

  const totalCommandes = commandesRows.reduce((s, c) => s + c.montant, 0);
  const totalFacture = res.totalDebit;
  const totalPaye = paiementsRows.reduce((s, p) => s + p.montant, 0);
  const totalAvoirs = res.lignes
    .filter((l) => l.type === "Avoir")
    .reduce((s, l) => s + Number(l.credit ?? 0), 0);

  const yyyy = new Date().getFullYear();
  const ref = `EC|${yyyy}|${(clientBlock.nom).replace(/\s+/g, "_").toUpperCase().slice(0, 20)}`;

  return generateEtatCompteClientPDF({
    reference: ref,
    periodeDebut: dateDebut,
    periodeFin: dateFin,
    client: clientBlock,
    soldeOuverture: res.soldeOuverture,
    lignes,
    commandes: commandesRows,
    paiements: paiementsRows,
    totalCommandes,
    totalFacture,
    totalPaye,
    totalAvoirs,
    ageing,
    note: res.emptyExplanation,
  });
}
