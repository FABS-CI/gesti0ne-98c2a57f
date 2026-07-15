export type EcritureFec = {
  ecriture_id: string;
  reference: string;
  date_ecriture: string;
  journal: string;
  libelle: string;
  lettrage: string | null;
  ecriture_lignes: {
    compte: string;
    compte_libelle: string;
    debit: number;
    credit: number;
  }[];
};

export type Issue = {
  line: number | null;
  reference: string;
  field: string;
  message: string;
};

export const SOCIETES = [{ code: "FABS", nom: "FABS Côte d'Ivoire" }];

export const FEC_HEADERS = [
  "JournalCode",
  "JournalLib",
  "EcritureNum",
  "EcritureDate",
  "CompteNum",
  "CompteLib",
  "CompAuxNum",
  "CompAuxLib",
  "PieceRef",
  "PieceDate",
  "EcritureLib",
  "Debit",
  "Credit",
  "EcritureLet",
  "DateLet",
  "ValidDate",
  "Montantdevise",
  "Idevise",
];

export const JOURNAL_LIB: Record<string, string> = {
  VT: "Ventes",
  AC: "Achats",
  BQ: "Banque",
  CA: "Caisse",
  OD: "Opérations diverses",
  PA: "Paie",
};

export function presetRange(v: string): { defaultFrom: string; defaultTo: string } {
  const now = new Date();
  const y = now.getFullYear();
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  if (v === "mois") {
    return {
      defaultFrom: iso(new Date(y, now.getMonth(), 1)),
      defaultTo: iso(new Date(y, now.getMonth() + 1, 0)),
    };
  }
  if (v === "trimestre") {
    const q = Math.floor(now.getMonth() / 3);
    return {
      defaultFrom: iso(new Date(y, q * 3, 1)),
      defaultTo: iso(new Date(y, q * 3 + 3, 0)),
    };
  }
  if (v === "annee_prec") {
    return { defaultFrom: `${y - 1}-01-01`, defaultTo: `${y - 1}-12-31` };
  }
  return { defaultFrom: `${y}-01-01`, defaultTo: `${y}-12-31` };
}

function fmtDate(d: string): string {
  return d.replace(/-/g, "").slice(0, 8);
}

function fmtMontant(n: number): string {
  return (Number(n) || 0).toFixed(2).replace(".", ",");
}

function sanitize(s: string | null | undefined): string {
  return (s ?? "").replace(/[|\r\n\t]/g, " ").trim();
}

export function validateEcritures(ecritures: EcritureFec[]): {
  blocking: Issue[];
  warnings: Issue[];
} {
  const blocking: Issue[] = [];
  const warnings: Issue[] = [];
  let fecLine = 1;
  for (const e of ecritures) {
    const ref = e.reference || e.ecriture_id.slice(0, 8);
    const headerLine = fecLine + 1;
    if (!e.journal)
      blocking.push({
        line: headerLine,
        reference: ref,
        field: "JournalCode",
        message: "Code journal manquant.",
      });
    if (!e.date_ecriture)
      blocking.push({
        line: headerLine,
        reference: ref,
        field: "EcritureDate",
        message: "Date d'écriture manquante.",
      });
    if (!e.libelle)
      warnings.push({
        line: headerLine,
        reference: ref,
        field: "EcritureLib",
        message: "Libellé d'écriture vide.",
      });
    if (!e.reference)
      warnings.push({
        line: headerLine,
        reference: e.ecriture_id.slice(0, 8),
        field: "PieceRef",
        message: "Référence de pièce vide.",
      });
    if (!e.ecriture_lignes?.length) {
      blocking.push({
        line: headerLine,
        reference: ref,
        field: "ecriture_lignes",
        message: "Aucune ligne — écriture ignorée par le FEC.",
      });
      continue;
    }
    let d = 0;
    let c = 0;
    e.ecriture_lignes.forEach((l, idx) => {
      const rowLine = fecLine + 1 + idx;
      if (!l.compte)
        blocking.push({
          line: rowLine,
          reference: ref,
          field: "CompteNum",
          message: `Compte manquant (ligne ${idx + 1} de l'écriture).`,
        });
      if (!l.compte_libelle)
        warnings.push({
          line: rowLine,
          reference: ref,
          field: "CompteLib",
          message: `Libellé de compte vide pour ${l.compte || "?"}.`,
        });
      d += Number(l.debit) || 0;
      c += Number(l.credit) || 0;
    });
    if (Math.round((d - c) * 100) !== 0) {
      blocking.push({
        line: headerLine,
        reference: ref,
        field: "Debit/Credit",
        message: `Écriture déséquilibrée (D=${d.toFixed(2)} · C=${c.toFixed(2)}).`,
      });
    }
    fecLine += e.ecriture_lignes.length;
  }
  return { blocking, warnings };
}

export function buildFecContent(ecritures: EcritureFec[]): string {
  const lines: string[] = [FEC_HEADERS.join("|")];
  ecritures.forEach((e, idx) => {
    const num = String(idx + 1).padStart(6, "0");
    e.ecriture_lignes.forEach((l) => {
      lines.push(
        [
          sanitize(e.journal),
          sanitize(JOURNAL_LIB[e.journal] ?? e.journal),
          num,
          fmtDate(e.date_ecriture),
          sanitize(l.compte),
          sanitize(l.compte_libelle),
          "",
          "",
          sanitize(e.reference),
          fmtDate(e.date_ecriture),
          sanitize(e.libelle),
          fmtMontant(Number(l.debit)),
          fmtMontant(Number(l.credit)),
          sanitize(e.lettrage),
          "",
          fmtDate(e.date_ecriture),
          "",
          "",
        ].join("|"),
      );
    });
  });
  return lines.join("\r\n");
}

export function downloadBlob(blob: Blob, name: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
