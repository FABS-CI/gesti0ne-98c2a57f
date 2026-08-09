import {
  PDFDocument,
  rgb,
  StandardFonts,
  type PDFPage,
  type PDFFont,
  type PDFImage,
  type RGB,
} from "pdf-lib";
import fabsLogoUrl from "@/assets/fabs-logo.png";
import { generateUnifiedCommercialPDF, generateUnifiedStatementPDF, generateUnifiedAchatPDF } from "./unified-generator";

// ----------------------------------------------------------------------------
// Types partagés par les différents générateurs (exportés pour compatibilité)
// ----------------------------------------------------------------------------

export type DocLigne = {
  num?: number;
  code?: string;
  designation?: string;
  total?: number;
  pu?: number;
  classe?: string;
  cycle?: string;
  niveau?: string;
  matiere?: string;
  codeArticle?: string;
  reference?: string;
  unite?: string;
  qte?: number;
  qteCommandee?: number;
  qteLivree?: number;
  qteRetournee?: number;
  motif?: string;
  prixUnitaire?: number;
  montant?: number;
  remisePct?: number;
  remiseMontant?: number;
  tvaPct?: number;
};

export type DocStatut = {
  label: string;
  color?: string;
};

export type DocBase = {
  id?: string;
  facture_id?: string;
  commande_id?: string;
  proforma_id?: string;
  bl_id?: string;
  br_id?: string;
  reference: string;
  date: string;
  clientNom?: string | null;
  clientTel?: string | null;
  representant?: string | null;
  representantTel?: string | null;
  codeClient?: string | null;
  adresseClient?: string | null;
  villeClient?: string | null;
  communeClient?: string | null;
  paysClient?: string | null;
  emailClient?: string | null;
  ncc?: string | null;
  rccm?: string | null;
  modePaiement?: string | null;
  lignes?: DocLigne[];
  totalVente?: number;
  remisePct?: number;
  remise?: number;
  remiseLigneTotal?: number;
  remiseGlobale?: number;
  remiseGlobalePct?: number;
  montantHT?: number;
  tvaPct?: number;
  tva?: number;
  totalTTC?: number;
  paye?: number;
  soldeDu?: number;
  livreurNom?: string | null;
  dateReceptionClient?: string | null;
  nomReceptionnaireClient?: string | null;
  statut?: DocStatut | null;
  notes?: string | null;
};

export type EtatCompteLigne = {
  date: string;
  reference: string;
  libelle: string;
  debit?: number;
  credit?: number;
  solde?: number;
  type?: string;
};

export type EtatCompteAgeing = {
  nonEchu: number;
  j0_30: number;
  j31_60: number;
  j61_90: number;
  j90plus: number;
};

export type EtatCompteData = {
  client_id?: string;
  reference?: string;
  periodeDebut?: string | null;
  periodeFin?: string | null;
  client?: {
    nom: string;
    reference?: string | null;
    adresse?: string | null;
    telephone?: string | null;
    email?: string | null;
    representant?: string | null;
    ville?: string | null;
  };
  lignes: EtatCompteLigne[];
  soldeOuverture?: number;
  ageing?: EtatCompteAgeing | null;
};

export type IncidentLignePdf = {
  numero: number;
  reference: string;
  designation: string;
  quantite: number;
  unite: string;
  valeurUnitaire: number;
  valeurTotale: number;
  observation: string;
};

export type IncidentPdfData = {
  numero: string;
  dateIncident: string;
  heureIncident: string | null;
  depot: string | null;
  magasin: string | null;
  responsable: string | null;
  typeIncident: string;
  statut: { label: string; color: string } | null;
  gravite: string | null;
  declarant: string | null;
  dateDeclaration: string;
  motif: string | null;
  observations: string | null;
  lignes: IncidentLignePdf[];
};

export type RapportIncidentsData = {
  reference: string;
  periodeLabel: string;
  filtresLabel: string | null;
  lignes: any[];
};

// ----------------------------------------------------------------------------
// Export des fonctions de génération
// ----------------------------------------------------------------------------

export async function generateFacturePDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Facture", data);
}

export async function generateProformaPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Proforma", data);
}

export async function generateBonCommandePDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Commande", data);
}

export async function generateBonLivraisonPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Bon de Livraison", data);
}

export async function generateBonRetourPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Bon de Retour", data);
}

export async function generateBonRemiseSpecimensPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Spécimens", data);
}

export async function generateBonTransfertPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Bon de Livraison", data); // Ou un type spécifique si existant
}

export async function generateEtatCompteClientPDF(data: EtatCompteData): Promise<Blob> {
  return generateUnifiedStatementPDF(data);
}

export async function generateApprovisionnementPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedAchatPDF(data);
}

export async function generateRecuPaiementPDF(data: DocBase): Promise<Blob> {
  return generateUnifiedCommercialPDF("Facture", data); // Stub à affiner si besoin d'un layout reçu spécifique
}

// Stubs pour les PDF d'incidents (à implémenter si nécessaire dans unified-generator)
export async function generateIncidentPDF(data: IncidentPdfData): Promise<Blob> {
  console.warn("generateIncidentPDF non encore migré vers le nouveau moteur");
  return new Blob([], { type: "application/pdf" });
}

export async function generateRapportIncidentsPDF(data: RapportIncidentsData): Promise<Blob> {
  console.warn("generateRapportIncidentsPDF non encore migré vers le nouveau moteur");
  return new Blob([], { type: "application/pdf" });
}

// ----------------------------------------------------------------------------
// Utilitaires système (Action et QR)
// ----------------------------------------------------------------------------

/** Déclenche le téléchargement direct d'un Blob PDF. */
export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 100);
}

/** Génère un nom de fichier standardisé. */
export function fileNameFor(reference: string, clientNom?: string | null): string {
  const safeRef = reference.replace(/[^a-z0-9]/gi, "_");
  const safeClient = clientNom ? `_${clientNom.replace(/[^a-z0-9]/gi, "_")}` : "";
  return `${safeRef}${safeClient}.pdf`.toUpperCase();
}

/** Build QR payload for verification. */
export function buildQrPayload(data: DocBase): string {
  return JSON.stringify({
    ref: data.reference,
    cli: data.clientNom,
    date: data.date,
    tot: data.totalTTC || data.montantHT,
  });
}
