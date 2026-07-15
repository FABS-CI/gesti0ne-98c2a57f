import type { Employe } from "@/lib/rh-api";
import type { EngineResult } from "@/lib/paie/engine";
import { generateBulletinPaieCIPDF, ENTREPRISE_FABS } from "@/lib/pdf/bulletinPaieCI";

export type CustomField = { label: string; valeur: string };

export function defaultPeriode(): string {
  const d = new Date();
  return d
    .toLocaleDateString("fr-FR", { month: "long", year: "numeric" })
    .replace(/^./, (c) => c.toUpperCase());
}

export interface BuildPdfArgs {
  employe: Employe;
  result: EngineResult;
  periode: string;
  observations: string;
  customFields: CustomField[];
  pageMargin: number;
  baseFontSize: number;
}

export async function buildBulletinPdfBlob(a: BuildPdfArgs): Promise<Blob> {
  const { employe, result, periode, observations, customFields, pageMargin, baseFontSize } = a;
  const ref = `BP|${periode.replace(/\s+/g, "-")}|${employe.matricule}`;
  return generateBulletinPaieCIPDF(
    {
      reference: ref,
      entreprise: ENTREPRISE_FABS,
      salarie: {
        matricule: employe.matricule,
        nomComplet: employe.nom_complet,
        fonction: employe.poste ?? undefined,
        departement: employe.departement,
        dateEmbauche: employe.date_embauche,
      },
      periode: {
        periode,
        mois: periode,
        annee: new Date().getFullYear(),
        dateEdition: new Date().toISOString(),
      },
      gains: result.lignes
        .filter((l) => l.gain > 0)
        .map((l) => ({
          code: l.code,
          libelle: l.libelle,
          base: l.base,
          taux: l.taux,
          montant: l.gain,
        })),
      retenues: result.lignes
        .filter((l) => l.retenue > 0)
        .map((l) => ({
          code: l.code,
          libelle: l.libelle,
          base: l.base,
          taux: l.taux,
          montant: l.retenue,
        })),
      patronales: result.lignes
        .filter((l) => l.patronale > 0)
        .map((l) => ({
          code: l.code,
          libelle: l.libelle,
          base: l.base,
          taux: l.taux,
          montant: l.patronale,
        })),
      totaux: {
        totalGains: result.salaireBrut,
        totalRetenues: result.totalRetenues,
        salaireBrut: result.salaireBrut,
        salaireImposable: result.salaireBrutImposable,
        netAPayer: result.salaireNet,
        coutEmployeur: result.coutEmployeur,
      },
      observations: observations || undefined,
      champsPersonnalises: customFields.filter((c) => c.label.trim() && c.valeur.trim()),
    },
    { margin: pageMargin, baseFontSize },
  );
}
