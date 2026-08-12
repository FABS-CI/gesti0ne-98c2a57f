// Construit un relevé bancaire client unique : factures, paiements et retours.
import { supabase } from "@/integrations/supabase/client";
import {
  generateEtatCompteClientPDF,
  type EtatCompteLigne,
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

  // Le relevé présente tout l'historique réel, sans report ni solde d'ouverture.
  const [{ data: factures }, { data: paiements }, { data: avoirs }] =
    await Promise.all([
      supabase
        .from("factures")
        .select("facture_id, reference, date_facture, date_echeance, montant_total, montant_paye, statut")
        .eq("client_id", args.clientId)
        .order("date_facture", { ascending: true }),
      supabase
        .from("paiements")
        .select(
          "facture_id, reference, date_paiement, montant, statut, factures!inner(client_id)",
        )
        .eq("factures.client_id", args.clientId)
        .order("date_paiement", { ascending: true }),
      supabase
        .from("retours")
        .select("reference, date_retour, montant, statut, facture_id")
        .eq("client_id", args.clientId)
        .neq("statut", "annule")
        .order("date_retour", { ascending: true }),
    ]);

  const paiementsFlat = (paiements ?? []).map((p) => ({
    reference: p.reference,
    date_paiement: p.date_paiement,
    montant: p.montant,
    statut: p.statut ?? null,
  }));

  const facturesCompte = ((factures ?? []) as FactureCompteRow[]).filter(
    (f) => !["annule", "annulee", "avoir"].includes((f.statut ?? "").toLowerCase()),
  );
  const retoursCompte = ((avoirs ?? []) as RetourCompteRow[]).filter((r) =>
    ["valide", "accepte", "valide_compta"].includes((r.statut ?? "").toLowerCase()),
  );
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
    dateDebut: null,
    dateFin: null,
    soldeOuvertureRow: 0,
    factures: facturesReleve,
    paiements: paiementsFlat,
    avoirs: avoirsReleve,
  });

  // Statut retour par facture (référence facture → aucun/partiel/total)
  const statutRetourParFacture = new Map<string, "aucun" | "partiel" | "total">();
  for (const f of facturesReleve) {
    const totalRet = retoursParFacture.get(f.facture_id) ?? 0;
    const brut = Number(f.montant_total ?? 0); // ici, montant_total est déjà reconstitué (brut)
    const net = brut - totalRet;
    const ref = f.reference ?? "";
    if (!ref) continue;
    if (totalRet <= 0) statutRetourParFacture.set(ref, "aucun");
    else if (net <= 0.5) statutRetourParFacture.set(ref, "total");
    else statutRetourParFacture.set(ref, "partiel");
  }

  // --- Enrichit les lignes avec un libellé humain
  const lignes: EtatCompteLigne[] = res.lignes.map((l) => ({
    ...l,
    factureReference:
      l.type === "Avoir"
        ? factureRefParRetour.get(l.reference)
        : l.type === "Paiement"
          ? factureRefParId.get(
              String((paiements ?? []).find((p) => p.reference === l.reference)?.facture_id ?? ""),
            )
          : l.reference,
    libelle:
      l.type === "Facture"
        ? (() => {
            const st = statutRetourParFacture.get(l.reference);
            const suffix =
              st === "partiel" ? " (Retour partiel)" : st === "total" ? " (Retour total)" : "";
            return `Facture client ${l.reference}${suffix}`;
          })()
        : l.type === "Paiement"
          ? `Paiement de la facture ${factureRefParId.get(
              String((paiements ?? []).find((p) => p.reference === l.reference)?.facture_id ?? ""),
            ) ?? "—"}`
          : l.type === "Avoir"
            ? `Retour sur facture ${factureRefParRetour.get(l.reference) ?? "—"}`
            : "",
  }));

  const ref = cli?.reference || "RELEVÉ"; // Plus d'identifiant technique composite


  return generateEtatCompteClientPDF({
    reference: ref,
    client: clientBlock,
    lignes,
  });
}
