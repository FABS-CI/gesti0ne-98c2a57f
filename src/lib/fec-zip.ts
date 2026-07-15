import JSZip from "jszip";
import { getBalance, getLignesPeriode } from "@/lib/compta-api";
import {
  generateBalancePDF,
  generateGrandLivrePDF,
  generateJournalComptablePDF,
} from "@/lib/pdf/pdfGenerator";
import { downloadBlob, type EcritureFec } from "@/lib/fec-helpers";

export interface FecZipParams {
  societe: string;
  dateFrom: string;
  dateTo: string;
  fecName: string;
  fecContent: string;
  ecritures: EcritureFec[];
  cancelRef: { current: { cancelled: boolean } };
  bump: (pct: number, label: string) => void;
}

export async function buildFecZip(p: FecZipParams): Promise<void> {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("fec.generer");
  const { societe, dateFrom, dateTo, fecName, fecContent, ecritures, cancelRef, bump } = p;
  const checkCancel = () => {
    if (cancelRef.current.cancelled) throw new Error("Génération annulée.");
  };
  bump(5, "Préparation du FEC…");
  checkCancel();
  const zipFile = new JSZip();
  zipFile.file(fecName, fecContent);

  bump(20, "Génération de la Balance PDF…");
  checkCancel();
  const balance = await getBalance(dateFrom, dateTo);
  checkCancel();
  if (balance.length) {
    const blob = (await generateBalancePDF(balance, { dateFrom, dateTo }, "blob")) as Blob;
    zipFile.file(`Balance_${dateFrom}_${dateTo}.pdf`, blob);
  }

  bump(45, "Génération du Grand livre PDF…");
  checkCancel();
  const lignes = await getLignesPeriode(dateFrom, dateTo);
  checkCancel();
  if (lignes.length) {
    const sorted = [...lignes].sort((a, b) => a.compte.localeCompare(b.compte));
    let solde = 0;
    let last = "";
    const pdfLignes = sorted.map((l) => {
      if (l.compte !== last) {
        solde = 0;
        last = l.compte;
      }
      solde += Number(l.debit) - Number(l.credit);
      return {
        compte: l.compte,
        compte_libelle: l.compte_libelle,
        date_ecriture: l.date_ecriture,
        journal: l.journal,
        reference: l.reference,
        libelle: l.libelle,
        debit: l.debit,
        credit: l.credit,
        solde,
      };
    });
    const blob = (await generateGrandLivrePDF(pdfLignes, { dateFrom, dateTo }, "blob")) as Blob;
    zipFile.file(`GrandLivre_${dateFrom}_${dateTo}.pdf`, blob);
  }

  bump(70, "Génération du Journal comptable PDF…");
  checkCancel();
  const url = await generateJournalComptablePDF(
    ecritures.map((e) => ({
      reference: e.reference,
      date_ecriture: e.date_ecriture,
      journal: e.journal,
      libelle: e.libelle,
      lettrage: e.lettrage,
      ecriture_lignes: e.ecriture_lignes,
    })),
    { dateFrom, dateTo },
    "preview",
  );
  if (typeof url === "string") {
    const blob = await (await fetch(url)).blob();
    URL.revokeObjectURL(url);
    zipFile.file(`JournalComptable_${dateFrom}_${dateTo}.pdf`, blob);
  }

  bump(90, "Compression de l'archive…");
  checkCancel();
  const bundle = await zipFile.generateAsync({ type: "blob" });
  checkCancel();
  downloadBlob(bundle, `Comptabilite_${societe}_${dateFrom}_${dateTo}.zip`);
  bump(100, "Terminé");
}
