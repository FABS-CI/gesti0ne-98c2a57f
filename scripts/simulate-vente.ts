import { mkdirSync, writeFileSync } from "fs";
import {
  generateProformaPDF,
  generateBonCommandePDF,
  generateBonLivraisonPDF,
  generateFacturePDF,
  generateRecuPaiementPDF,
  fileNameFor,
} from "../src/lib/pdf/fabsTemplates";

const OUT = "/mnt/documents/simulation-vente";
mkdirSync(OUT, { recursive: true });

const client = {
  clientNom: "LIBRAIRIE MODERNE COCODY",
  clientTel: "+225 07 08 12 34 56",
  representant: "M. OUATTARA",
  modePaiement: "Paiement à la livraison",
};

const lignes = [
  {
    classe: "Terminale",
    codeArticle: "FABS-CI78",
    reference: "TEST PHYSIQUE-CHIMIE BAC",
    qte: 50,
    qteCommandee: 50,
    qteLivree: 50,
    prixUnitaire: 4000,
    montant: 200000,
  },
  {
    classe: "3ème",
    codeArticle: "FABS-CI45",
    reference: "CAHIER D'EXERCICES MATHS BREVET",
    qte: 30,
    qteCommandee: 30,
    qteLivree: 30,
    prixUnitaire: 2500,
    montant: 75000,
  },
  {
    classe: "6ème",
    codeArticle: "FABS-CI92",
    reference: "LIVRE LECTURE CM2-6EME",
    qte: 20,
    qteCommandee: 20,
    qteLivree: 20,
    prixUnitaire: 3200,
    montant: 64000,
  },
];

const totaux = {
  totalVente: 339000,
  remisePct: 20,
  remise: 67800,
  montantHT: 271200,
  tvaPct: 18,
  tva: 48816,
  totalTTC: 320016,
  paye: 100000,
  soldeDu: 220016,
};

const base = { ...client, lignes, ...totaux, date: "2026-06-28" };

async function save(name: string, blob: Blob) {
  const buf = Buffer.from(await blob.arrayBuffer());
  writeFileSync(`${OUT}/${name}`, buf);
  console.log("écrit:", name, buf.length, "octets");
}

async function main() {
  await save(
    fileNameFor("FABS|PF|26|00001", client.clientNom),
    await generateProformaPDF({ ...base, reference: "FABS|PF|26|00001" }),
  );
  await save(
    fileNameFor("FABS|BC|26|00001", client.clientNom),
    await generateBonCommandePDF({ ...base, reference: "FABS|BC|26|00001" }),
  );
  await save(
    fileNameFor("FABS|BL|26|00001", client.clientNom),
    await generateBonLivraisonPDF({ ...base, reference: "FABS|BL|26|00001" }),
  );
  await save(
    fileNameFor("FABS|FC|26|00001", client.clientNom),
    await generateFacturePDF({ ...base, reference: "FABS|FC|26|00001" }),
  );
  await save(
    fileNameFor("FABS|RP|26|00001", client.clientNom),
    await generateRecuPaiementPDF({
      ...client,
      date: "2026-06-28",
      reference: "FABS|RP|26|00001",
      montant: 100000,
      montantEnLettres: "CENT MILLE FRANCS",
      factureReference: "FABS|FC|26|00001",
      modePaiement: "Espèces",
      representant: "KONE IBRAHIM",
      resteDu: 220016,
    }),
  );
}

main()
  .then(() => console.log("OK"))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
