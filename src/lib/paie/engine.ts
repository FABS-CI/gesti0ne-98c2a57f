// Moteur de calcul de paie CI paramétrable (lit paie_parametres / paie_rubriques)
import type { PaieParametre, PaieRubrique } from "./parametres-api";
import { paramMap } from "./parametres-api";

export interface EngineInput {
  salaireBase: number;
  primes?: number;
  heuresSup?: number;
  rubriquesCustom?: Array<{
    code: string;
    libelle: string;
    type: "gain" | "retenue";
    montant: number;
  }>;
}

export interface LigneBulletin {
  code: string;
  libelle: string;
  base: number;
  taux: number;
  gain: number;
  retenue: number;
  patronale: number;
}

export interface EngineResult {
  lignes: LigneBulletin[];
  salaireBrut: number;
  salaireBrutImposable: number;
  totalGains: number;
  totalRetenues: number;
  totalPatronales: number;
  cnpsSalarie: number;
  cnpsPatronal: number;
  cmuSalarie: number;
  cmuPatronal: number;
  its: number;
  cn: number;
  salaireNet: number;
  coutEmployeur: number;
}

function calculITS(base: number, p: Record<string, number>): number {
  if (base <= 0) return 0;
  const t1 = p["ITS_TRANCHE1_MAX"] ?? 75000;
  const t2 = p["ITS_TRANCHE2_MAX"] ?? 240000;
  const t3 = p["ITS_TRANCHE3_MAX"] ?? 800000;
  const t4 = p["ITS_TRANCHE4_MAX"] ?? 2400000;
  const r1 = (p["ITS_TRANCHE1_TAUX"] ?? 1.5) / 100;
  const r2 = (p["ITS_TRANCHE2_TAUX"] ?? 5) / 100;
  const r3 = (p["ITS_TRANCHE3_TAUX"] ?? 10) / 100;
  const r4 = (p["ITS_TRANCHE4_TAUX"] ?? 15) / 100;
  const r5 = (p["ITS_TRANCHE5_TAUX"] ?? 20) / 100;
  let its = 0;
  let prev = 0;
  for (const [max, taux] of [
    [t1, r1],
    [t2, r2],
    [t3, r3],
    [t4, r4],
    [Infinity, r5],
  ] as [number, number][]) {
    if (base <= prev) break;
    its += (Math.min(base, max) - prev) * taux;
    prev = max;
  }
  return Math.round(its);
}

export function runEngine(
  input: EngineInput,
  parametres: PaieParametre[],
  rubriques: PaieRubrique[],
): EngineResult {
  const p = paramMap(parametres);
  const salaireBase = Math.max(0, input.salaireBase || 0);
  const primes = Math.max(0, input.primes || 0);
  const heuresSup = Math.max(0, input.heuresSup || 0);

  const lignes: LigneBulletin[] = [];
  const push = (l: Partial<LigneBulletin>): void => {
    lignes.push({
      code: l.code ?? "",
      libelle: l.libelle ?? "",
      base: l.base ?? 0,
      taux: l.taux ?? 0,
      gain: l.gain ?? 0,
      retenue: l.retenue ?? 0,
      patronale: l.patronale ?? 0,
    });
  };

  // Gains
  push({ code: "SB", libelle: "Salaire de base", gain: salaireBase, base: salaireBase });
  if (primes) push({ code: "PRIMES", libelle: "Primes / Indemnités", gain: primes });
  if (heuresSup) push({ code: "HS", libelle: "Heures supplémentaires", gain: heuresSup });

  // Rubriques custom (gains)
  for (const rc of input.rubriquesCustom ?? []) {
    if (rc.type === "gain") push({ code: rc.code, libelle: rc.libelle, gain: rc.montant });
  }

  // Rubriques configurables actives (gains uniquement — retenues via barème CI)
  for (const r of rubriques.filter(
    (x) => x.actif && x.type === "gain" && !["SB"].includes(x.code),
  )) {
    let montant = 0;
    if (r.mode_calcul === "fixe") montant = r.montant_fixe;
    else if (r.mode_calcul === "pourcentage") montant = Math.round((salaireBase * r.taux) / 100);
    if (montant > 0)
      push({ code: r.code, libelle: r.libelle, base: salaireBase, taux: r.taux, gain: montant });
  }

  const totalGains = lignes.reduce((s, l) => s + l.gain, 0);
  const salaireBrut = totalGains;

  // Retenues CI
  const plafondCNPS = p["CNPS_PLAFOND_MENSUEL"] ?? 2700000;
  const baseCNPS = Math.min(salaireBrut, plafondCNPS);
  const cnpsSalarie = Math.round((baseCNPS * (p["CNPS_SALARIE_RETRAITE"] ?? 6.3)) / 100);
  const cmuSalarie = p["CMU_SALARIE"] ?? 1000;

  const abattement = (p["ABATTEMENT_ITS"] ?? 20) / 100;
  const salaireBrutImposable = Math.max(
    0,
    Math.round(salaireBrut * (1 - abattement) - cnpsSalarie),
  );
  const its = calculITS(salaireBrutImposable, p);
  const cn = Math.round((salaireBrutImposable * (p["CN_TAUX"] ?? 1.5)) / 100);

  push({
    code: "CNPS_SAL",
    libelle: "CNPS Retraite (6,3%)",
    base: baseCNPS,
    taux: p["CNPS_SALARIE_RETRAITE"] ?? 6.3,
    retenue: cnpsSalarie,
  });
  push({ code: "CMU_SAL", libelle: "CMU salarié", retenue: cmuSalarie });
  push({
    code: "ITS",
    libelle: "ITS (Impôt sur salaire)",
    base: salaireBrutImposable,
    retenue: its,
  });
  push({
    code: "CN",
    libelle: "Contribution Nationale",
    base: salaireBrutImposable,
    taux: p["CN_TAUX"] ?? 1.5,
    retenue: cn,
  });

  // Retenues custom
  for (const rc of input.rubriquesCustom ?? []) {
    if (rc.type === "retenue") push({ code: rc.code, libelle: rc.libelle, retenue: rc.montant });
  }

  // Charges patronales
  const cnpsPatronal = Math.round((baseCNPS * (p["CNPS_PATRONAL_RETRAITE"] ?? 7.7)) / 100);
  const pf = Math.round((salaireBrut * (p["CNPS_PATRONAL_PF"] ?? 5.75)) / 100);
  const at = Math.round((salaireBrut * (p["CNPS_PATRONAL_AT"] ?? 2)) / 100);
  const cmuPatronal = p["CMU_PATRONAL"] ?? 1000;
  push({
    code: "CNPS_PAT",
    libelle: "CNPS patronale retraite",
    base: baseCNPS,
    taux: p["CNPS_PATRONAL_RETRAITE"] ?? 7.7,
    patronale: cnpsPatronal,
  });
  push({
    code: "PF",
    libelle: "Prestations familiales",
    base: salaireBrut,
    taux: p["CNPS_PATRONAL_PF"] ?? 5.75,
    patronale: pf,
  });
  push({
    code: "AT",
    libelle: "Accident du travail",
    base: salaireBrut,
    taux: p["CNPS_PATRONAL_AT"] ?? 2,
    patronale: at,
  });
  push({ code: "CMU_PAT", libelle: "CMU patronale", patronale: cmuPatronal });

  const totalRetenues = lignes.reduce((s, l) => s + l.retenue, 0);
  const totalPatronales = lignes.reduce((s, l) => s + l.patronale, 0);
  const salaireNet = salaireBrut - totalRetenues;
  const coutEmployeur = salaireBrut + totalPatronales;

  return {
    lignes,
    salaireBrut,
    salaireBrutImposable,
    totalGains,
    totalRetenues,
    totalPatronales,
    cnpsSalarie,
    cnpsPatronal,
    cmuSalarie,
    cmuPatronal,
    its,
    cn,
    salaireNet,
    coutEmployeur,
  };
}
