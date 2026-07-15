// Moteur de calcul de paie — Côte d'Ivoire (barèmes 2024)
// Toutes les valeurs sont en FCFA.

export const PLAFOND_CNPS = 1_647_315; // plafond mensuel cotisations retraite

// Taux CNPS / charges
export const TAUX = {
  cnpsSalarie: 0.063, // retraite salarié (plafonné)
  cnpsEmployeurRetraite: 0.077, // retraite employeur (plafonné)
  prestationsFamiliales: 0.0575, // employeur, sans plafond
  accidentTravail: 0.03, // employeur, 2-5% selon secteur (défaut 3%)
  formationPro: 0.012, // employeur
  abattementIR: 0.15, // abattement forfaitaire avant IR
} as const;

export interface BulletinParams {
  salaireBase: number;
  primes?: number;
  heuresSup?: number; // montant des heures supplémentaires
}

export interface BulletinResult {
  salaireBrut: number;
  cotisationCNPSSalarie: number;
  cotisationCNPSEmployeur: number;
  prestationsFamiliales: number;
  accidentTravail: number;
  formationPro: number;
  baseIR: number;
  montantIR: number;
  salaireNet: number;
  chargesTotalesEmployeur: number;
  coutTotalEmployeur: number;
}

// Barème IR progressif mensuel (CI)
function calculIR(baseImposable: number): number {
  const tranches = [
    { plafond: 75_000, taux: 0 },
    { plafond: 240_000, taux: 0.16 },
    { plafond: 800_000, taux: 0.21 },
    { plafond: Infinity, taux: 0.24 },
  ];
  let ir = 0;
  let precedent = 0;
  for (const t of tranches) {
    if (baseImposable <= precedent) break;
    const montantDansTranche = Math.min(baseImposable, t.plafond) - precedent;
    ir += montantDansTranche * t.taux;
    precedent = t.plafond;
  }
  return Math.round(ir);
}

export function calculateBulletin(params: BulletinParams): BulletinResult {
  const salaireBase = Math.max(0, params.salaireBase || 0);
  const primes = Math.max(0, params.primes || 0);
  const heuresSup = Math.max(0, params.heuresSup || 0);

  const salaireBrut = salaireBase + primes + heuresSup;
  const baseCNPS = Math.min(salaireBrut, PLAFOND_CNPS);

  const cotisationCNPSSalarie = Math.round(baseCNPS * TAUX.cnpsSalarie);
  const cotisationCNPSEmployeur = Math.round(baseCNPS * TAUX.cnpsEmployeurRetraite);
  const prestationsFamiliales = Math.round(salaireBrut * TAUX.prestationsFamiliales);
  const accidentTravail = Math.round(salaireBrut * TAUX.accidentTravail);
  const formationPro = Math.round(salaireBrut * TAUX.formationPro);

  // Base IR : brut diminué de l'abattement forfaitaire et des cotisations salarié
  const baseIR = Math.max(
    0,
    Math.round(salaireBrut * (1 - TAUX.abattementIR) - cotisationCNPSSalarie),
  );
  const montantIR = calculIR(baseIR);

  const salaireNet = salaireBrut - cotisationCNPSSalarie - montantIR;

  const chargesTotalesEmployeur =
    cotisationCNPSEmployeur + prestationsFamiliales + accidentTravail + formationPro;
  const coutTotalEmployeur = salaireBrut + chargesTotalesEmployeur;

  return {
    salaireBrut,
    cotisationCNPSSalarie,
    cotisationCNPSEmployeur,
    prestationsFamiliales,
    accidentTravail,
    formationPro,
    baseIR,
    montantIR,
    salaireNet,
    chargesTotalesEmployeur,
    coutTotalEmployeur,
  };
}
