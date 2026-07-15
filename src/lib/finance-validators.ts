// Validateurs purs pour la logique financière (paiements, compta, paie).
// Découplés de Supabase pour être testables unitairement.

export type MontantValidation = { ok: true; montant: number } | { ok: false; error: string };

/** Vérifie qu'un montant est fini, > 0 et arrondi à l'unité (FCFA). */
export function validateMontantPaiement(raw: unknown): MontantValidation {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return { ok: false, error: "Montant invalide" };
  if (n <= 0) return { ok: false, error: "Le montant doit être strictement positif" };
  return { ok: true, montant: Math.round(n) };
}

/** Arrondi financier (FCFA, pas de décimales). */
export function arrondirFCFA(n: number): number {
  return Math.round(n);
}

export type EcritureLigne = { debit?: number | null; credit?: number | null };

/** Une écriture comptable est équilibrée si Σ débits = Σ crédits. */
export function ecritureEquilibree(lignes: EcritureLigne[], tolerance = 0): boolean {
  const totaux = lignes.reduce(
    (acc, l) => {
      acc.d += Number(l.debit ?? 0);
      acc.c += Number(l.credit ?? 0);
      return acc;
    },
    { d: 0, c: 0 },
  );
  return Math.abs(totaux.d - totaux.c) <= tolerance;
}

export type PaiementRef = {
  facture_id: string | null;
  montant: number;
  date_paiement: string;
  mode_paiement: string;
};

/** Détecte un doublon probable: même facture + même montant + même date + même mode. */
export function isDoublonPaiement(a: PaiementRef, b: PaiementRef): boolean {
  return (
    !!a.facture_id &&
    a.facture_id === b.facture_id &&
    arrondirFCFA(a.montant) === arrondirFCFA(b.montant) &&
    a.date_paiement === b.date_paiement &&
    a.mode_paiement === b.mode_paiement
  );
}

export type Periode = { debut: string; fin: string };

/** Deux périodes se chevauchent si debut1 <= fin2 && debut2 <= fin1 (bornes incluses). */
export function periodesChevauchent(a: Periode, b: Periode): boolean {
  return a.debut <= b.fin && b.debut <= a.fin;
}

/** Renvoie l'index de la première paire de périodes qui se chevauchent, ou -1. */
export function indexPremierChevauchement(periodes: Periode[]): number {
  for (let i = 0; i < periodes.length; i++) {
    for (let j = i + 1; j < periodes.length; j++) {
      if (periodesChevauchent(periodes[i], periodes[j])) return i;
    }
  }
  return -1;
}
