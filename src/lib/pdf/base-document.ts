
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
import { formatFCFA } from "@/lib/format";
import { buildQrUrl } from "./qr-logic";

// --- Configuration & Couleurs ---

export const COLORS = {
  bleuFabs: rgb(0.106, 0.165, 0.341), // #1B2A57
  rougeFabs: rgb(0.827, 0.184, 0.184), // #D32F2F (Couleur pour Remises)
  orangeFabs: rgb(0.96, 0.486, 0.0), // #F57C00 (Couleur pour ligne séparatrice et badge commande)
  grisClair: rgb(0.968, 0.968, 0.968), // #F7F7F7
  noir: rgb(0, 0, 0),
  blanc: rgb(1, 1, 1),
  grisTexte: rgb(0.3, 0.3, 0.3),
  grisLigne: rgb(0.82, 0.835, 0.86),
};

export const PAGE = { w: 595.28, h: 841.89 }; // A4
export const MARGINS = { x: 34, top: 40, bottom: 65 }; // Marges internes du contenu
export const CONTENT_W = PAGE.w - MARGINS.x * 2;

// --- Types ---

export type DocBase = {
  id: string; // UUID pour verification
  type: string;
  reference: string;
  date: string;
  heure?: string;
  commercial?: string;
  statut?: string;
  client: {
    nom: string;
    ville?: string;
    adresse?: string;
    representant?: string;
    telephone?: string;
    email?: string;
    code?: string;
  };
};

export type DocLigne = {
  num: number;
  code: string;
  designation: string;
  classe?: string;
  qte: number;
  pu: number;
  remisePct?: number;
  total: number;
};

export type DocTotals = {
  sousTotal: number;
  remiseLignes?: number;
  remiseLignesPct?: number;
  remiseGlobale?: number;
  remiseGlobalePct?: number;
  tva?: number;
  frais?: number;
  totalAPayer: number;
  montantLettres: string;
};

// --- Engine ---

export class BaseDocument {
  doc!: PDFDocument;
  page!: PDFPage;
  fonts!: {
    regular: PDFFont;
    bold: PDFFont;
    italic: PDFFont;
    boldItalic: PDFFont;
  };
  logoImg: PDFImage | null = null;
  data: DocBase;
  totals: DocTotals;
  
  constructor(data: DocBase, totals: DocTotals) {
    this.data = data;
    this.totals = totals;
  }

  async init() {
    this.doc = await PDFDocument.create();
    
    // Charger les polices
    this.fonts = {
      regular: await this.doc.embedFont(StandardFonts.Helvetica),
      bold: await this.doc.embedFont(StandardFonts.HelveticaBold),
      italic: await this.doc.embedFont(StandardFonts.HelveticaOblique),
      boldItalic: await this.doc.embedFont(StandardFonts.HelveticaBoldOblique),
    };

    // Charger le logo
    try {
      const res = await fetch(fabsLogoUrl);
      const bytes = await res.arrayBuffer();
      this.logoImg = await this.doc.embedPng(bytes);
    } catch (e) {
      console.error("Erreur chargement logo:", e);
    }

    this.addNewPage();
  }

  addNewPage() {
    this.page = this.doc.addPage([PAGE.w, PAGE.h]);
    this.drawChrome();
  }

  // Dessine les éléments répétés sur chaque page (cadre, filigrane, header, footer)
  drawChrome() {
    this.drawFrame();
    this.drawWatermark();
    this.drawHeader();
    this.drawFooter();
  }

  drawFrame() {
    this.page.drawRectangle({
      x: 10,
      y: 10,
      width: PAGE.w - 20,
      height: PAGE.h - 20,
      borderColor: COLORS.bleuFabs,
      borderWidth: 0.5,
    });
  }

  drawWatermark() {
    if (!this.logoImg) return;
    const size = 300;
    this.page.drawImage(this.logoImg, {
      x: (PAGE.w - size) / 2,
      y: (PAGE.h - size) / 2,
      width: size,
      height: size,
      opacity: 0.05,
    });
  }

  drawHeader() {
    const yTop = PAGE.h - 25;
    
    // Logo (G)
    if (this.logoImg) {
      const h = 45;
      const w = (this.logoImg.width / this.logoImg.height) * h;
      this.page.drawImage(this.logoImg, { x: MARGINS.x, y: yTop - h, width: w, height: h });
      
      this.page.drawText("Une innovation pour une école de qualité", {
        x: MARGINS.x,
        y: yTop - h - 12,
        size: 8,
        font: this.fonts.italic,
      color: this.totals.montantLettres.includes("CFA") ? COLORS.orangeFabs : COLORS.grisTexte,
      });
    }

    // Titre (C)
    const displayType = this.data.type === "Commande" ? "BON DE COMMANDE" : this.data.type.toUpperCase();
    const titleSize = 28;
    const titleW = this.fonts.bold.widthOfTextAtSize(displayType, titleSize);
    this.page.drawText(displayType, {
      x: (PAGE.w - titleW) / 2,
      y: yTop - 28,
      size: titleSize,
      font: this.fonts.bold,
      color: COLORS.orangeFabs,
    });

    // Cartouche (D) - Déplacé un peu vers la droite pour éviter chevauchement si titre long
    const cartX = PAGE.w - MARGINS.x - 110;
    const cartY = yTop;
    
    this.page.drawRectangle({
      x: cartX,
      y: cartY - 18,
      width: 110,
      height: 18,
      color: COLORS.bleuFabs,
    });
    const refText = `N° ${this.data.reference}`;
    const refW = this.fonts.bold.widthOfTextAtSize(refText, 9);
    this.page.drawText(refText, {
      x: cartX + (110 - refW) / 2,
      y: cartY - 12,
      size: 9,
      font: this.fonts.bold,
      color: COLORS.blanc,
    });

    const details = [
      { l: "Date", v: this.data.date },
      { l: "Heure", v: this.data.heure ?? new Date().toLocaleTimeString("fr-FR", { hour: '2-digit', minute: '2-digit' }).replace(':', 'h') },
    ];

    details.forEach((d, i) => {
      const y = cartY - 32 - i * 11;
      this.page.drawText(`${d.l} :`, { x: cartX + 40, y, size: 8, font: this.fonts.regular, color: COLORS.noir });
      const valW = this.fonts.bold.widthOfTextAtSize(d.v, 8);
      this.page.drawText(d.v, { x: PAGE.w - MARGINS.x - valW, y, size: 8, font: this.fonts.bold, color: COLORS.noir });
    });

    this.page.drawLine({
      start: { x: MARGINS.x, y: yTop - 70 },
      end: { x: PAGE.w - MARGINS.x, y: yTop - 70 },
      color: COLORS.grisLigne,
      thickness: 0.5,
    });
  }

  drawFooter() {
    const yBot = 50;

    // Ligne orange au-dessus du pied de page
    this.page.drawLine({
      start: { x: MARGINS.x, y: 70 },
      end: { x: PAGE.w - MARGINS.x, y: 70 },
      thickness: 1,
      color: COLORS.orangeFabs,
    });
    
    // Colonnes Pied de page
    const colW = CONTENT_W / 3;
    const footerTextSize = 8;
    
    // Col 1 : Société
    this.page.drawText("EDITIONS FABS-CI", { x: MARGINS.x, y: yBot, size: footerTextSize + 1, font: this.fonts.bold });
    this.page.drawText("BP 673 Bingerville - Côte d'Ivoire", { x: MARGINS.x, y: yBot - 10, size: footerTextSize, font: this.fonts.regular });
    this.page.drawText("RCCM : CI-ABJ-2020-B-12345", { x: MARGINS.x, y: yBot - 19, size: footerTextSize, font: this.fonts.regular });

    // Col 2 : Contact
    this.page.drawText("CONTACT", { x: MARGINS.x + colW, y: yBot, size: footerTextSize + 1, font: this.fonts.bold });
    this.page.drawText("Tél: +225 07 59 73 71 23 / 01 50 48 51 88", { x: MARGINS.x + colW, y: yBot - 10, size: footerTextSize, font: this.fonts.regular });
    this.page.drawText("Email: edition693fabs@gmail.com", { x: MARGINS.x + colW, y: yBot - 19, size: footerTextSize, font: this.fonts.regular });

    // Col 3 : Banques
    this.page.drawText("BANQUES", { x: MARGINS.x + colW * 2, y: yBot, size: footerTextSize + 1, font: this.fonts.bold });
    this.page.drawText("CORIS BANK: 01011 007630824101 34", { x: MARGINS.x + colW * 2, y: yBot - 10, size: footerTextSize, font: this.fonts.regular });
    this.page.drawText("SGBCI: 01123012343259990 95", { x: MARGINS.x + colW * 2, y: yBot - 19, size: footerTextSize, font: this.fonts.regular });

    // Bandeau (conditionnel : seulement sur les Factures)
    if (this.data.type === "Facture") {
      const warningText = "IMPORTANT : Seuls les paiements effectués sur les numéros officiels indiqués au bloc CONTACT sont valables.";
      
      const warnY = 75; // Aligné sur la ligne orange

      // Texte unique optimisé
      const warnW1 = this.fonts.bold.widthOfTextAtSize(warningText, 8);
      this.page.drawText(warningText, {
        x: MARGINS.x + (CONTENT_W - warnW1) / 2,
        y: warnY + 5,
        size: 8,
        font: this.fonts.bold,
        color: COLORS.rougeFabs,
      });
    }

    // Pagination
    const pageCount = this.doc.getPageCount();
    const currPage = this.doc.getPages().indexOf(this.page) + 1;
    const paginText = `Page ${currPage} / ${pageCount}`;
    const paginW = this.fonts.regular.widthOfTextAtSize(paginText, 8);
    this.page.drawText(paginText, {
      x: PAGE.w - MARGINS.x - paginW,
      y: 15,
      size: 8,
      font: this.fonts.regular,
      color: COLORS.grisTexte,
    });
  }

  async drawClientAndQr(y: number): Promise<number> {
    const boxH = 90;
    const boxW = (CONTENT_W - 15) / 2;
    
    // Bloc Client
    this.page.drawRectangle({
      x: MARGINS.x,
      y: y - boxH,
      width: boxW,
      height: boxH,
      color: COLORS.grisClair,
      opacity: 0.5,
    });
    this.page.drawText("FACTURÉ À", { x: MARGINS.x + 10, y: y - 15, size: 7, font: this.fonts.bold, color: COLORS.bleuFabs });
    this.page.drawText(this.data.client.nom.toUpperCase(), { x: MARGINS.x + 10, y: y - 32, size: 12, font: this.fonts.bold, color: COLORS.bleuFabs });
    
    const kv = [
      { l: "Ville", v: this.data.client.ville ?? "—" },
      { l: "Représentant", v: this.data.client.representant ?? "—" },
      { l: "Téléphone", v: this.data.client.telephone ?? "—" },
    ];
    kv.forEach((item, i) => {
      this.page.drawText(`${item.l} :`, { x: MARGINS.x + 10, y: y - 48 - i * 11, size: 8, font: this.fonts.regular });
      this.page.drawText(item.v, { x: MARGINS.x + 80, y: y - 48 - i * 11, size: 8, font: this.fonts.bold });
    });

    // Bloc QR - Affiché uniquement si autorisé pour ce type de document (Facture seulement)
    // On extrait le préfixe de la référence (ex: FAC de FAC-2026-00001)
    const { shouldShowQr } = await import("./docTypeConfig");
    const prefix = this.data.reference.split('-')[0];
    
    if (shouldShowQr(prefix)) {
      const qrX = MARGINS.x + boxW + 15;
      this.page.drawRectangle({
        x: qrX,
        y: y - boxH,
        width: boxW,
        height: boxH,
        color: COLORS.grisClair,
        opacity: 0.5,
      });

      try {
        const { default: QRCode } = await import("qrcode");
        const url = buildQrUrl(this.data.reference);
        const qrDataUrl = await QRCode.toDataURL(url, { margin: 0, width: 120 });
        const qrImage = await this.doc.embedPng(qrDataUrl);
        this.page.drawImage(qrImage, { x: qrX + 10, y: y - boxH + 15, width: 60, height: 60 });
        
        this.page.drawText("Scanner pour vérifier", { x: qrX + 80, y: y - 40, size: 7, font: this.fonts.regular });
        this.page.drawText("l'authenticité", { x: qrX + 80, y: y - 50, size: 7, font: this.fonts.regular });
      } catch (e) {
        console.error("QR Error", e);
      }
    }

    return y - boxH - 20;
  }

  drawTable(y: number, colonnes: { label: string, key: string, width: number }[], lignes: DocLigne[], options?: { showClientReception?: boolean }): number {
    // Header
    this.page.drawRectangle({
      x: MARGINS.x,
      y: y - 20,
      width: CONTENT_W,
      height: 20,
      color: COLORS.bleuFabs,
    });

    let x = MARGINS.x;
    colonnes.forEach(col => {
      const txt = col.label.toUpperCase();
      const txtW = this.fonts.bold.widthOfTextAtSize(txt, 8);
      this.page.drawText(txt, {
        x: x + (col.width - txtW) / 2,
        y: y - 13,
        size: 8,
        font: this.fonts.bold,
        color: COLORS.blanc,
      });

      // Traits verticaux pour le header
      this.page.drawLine({
        start: { x, y },
        end: { x, y: y - 20 },
        color: COLORS.grisLigne,
        thickness: 0.5,
      });

      x += col.width;
    });

    // Dernier trait vertical à droite du header
    this.page.drawLine({
      start: { x, y },
      end: { x, y: y - 20 },
      color: COLORS.grisLigne,
      thickness: 0.5,
    });

    // Lignes
    let curY = y - 20;
    lignes.forEach((l, i) => {
      if (curY < MARGINS.bottom + 50) {
        this.addNewPage();
        curY = PAGE.h - 120; // Reprendre sous le header suite
      }
      
      const rowH = 22; // Hauteur augmentée pour la lisibilité
      if (i % 2 === 1) {
        this.page.drawRectangle({ 
          x: MARGINS.x, 
          y: curY - rowH, 
          width: CONTENT_W, 
          height: rowH, 
          color: COLORS.grisClair 
        });
      }

      let curX = MARGINS.x;
      colonnes.forEach(col => {
        let val = (l as any)[col.key];
        if (typeof val === 'number' && col.key !== 'num' && col.key !== 'qte' && col.key !== 'remisePct') {
          val = formatFCFA(val, false);
        } else if (col.key === 'remisePct' && val) {
          val = `${val} %`;
        }
        val = String(val ?? "");
        
        const fontSize = 10;
        const txtW = this.fonts.regular.widthOfTextAtSize(val, fontSize);
        const alignX = col.key === 'designation' ? curX + 5 : curX + (col.width - txtW) / 2;
        
        this.page.drawText(val, {
          x: alignX,
          y: curY - 15,
          size: fontSize,
          font: this.fonts.regular,
          color: (col.key === 'remisePct' || col.key === 'remiseMontant') ? COLORS.rougeFabs : COLORS.noir,
        });

        // Dessiner les traits verticaux des colonnes
        this.page.drawLine({
          start: { x: curX, y: curY },
          end: { x: curX, y: curY - rowH },
          color: COLORS.grisLigne,
          thickness: 0.5,
        });

        curX += col.width;
      });

      // Dernier trait vertical à droite
      this.page.drawLine({
        start: { x: curX, y: curY },
        end: { x: curX, y: curY - rowH },
        color: COLORS.grisLigne,
        thickness: 0.5,
      });

      // Trait horizontal sous la ligne
      this.page.drawLine({
        start: { x: MARGINS.x, y: curY - rowH },
        end: { x: PAGE.w - MARGINS.x, y: curY - rowH },
        color: COLORS.grisLigne,
        thickness: 0.5,
      });
      curY -= rowH;

    });

    if (options?.showClientReception) {
      this.drawClientReception(curY - 20);
    }

    return curY - 20;
  }

  drawClientReception(y: number) {
    const boxW = 150;
    const x = MARGINS.x;
    this.page.drawText("RÉCEPTION CLIENT", {
      x: x,
      y: y - 15,
      size: 9,
      font: this.fonts.bold,
      color: COLORS.bleuFabs,
    });
    this.page.drawRectangle({
      x: x,
      y: y - 80,
      width: boxW,
      height: 60,
      borderColor: COLORS.grisLigne,
      borderWidth: 0.5,
    });
    this.page.drawText("(Nom et signature)", {
      x: x + 5,
      y: y - 75,
      size: 7,
      font: this.fonts.italic,
      color: COLORS.grisTexte,
    });
  }


  drawTotals(y: number): number {
    const boxW = 200;
    const x = PAGE.w - MARGINS.x - boxW;
    let curY = y;

    const row = (label: string, value: string, isTotal = false) => {
      if (isTotal) {
        this.page.drawRectangle({ x, y: curY - 20, width: boxW, height: 20, color: COLORS.bleuFabs });
        this.page.drawText(label, { x: x + 5, y: curY - 13, size: 9, font: this.fonts.bold, color: COLORS.blanc });
        const valW = this.fonts.bold.widthOfTextAtSize(value, 10);
        this.page.drawText(value, { x: PAGE.w - MARGINS.x - valW - 5, y: curY - 13, size: 10, font: this.fonts.bold, color: COLORS.blanc });
      } else {
        const isRemise = label.toLowerCase().includes('remise');
        this.page.drawText(label, { 
          x: x + 5, 
          y: curY - 13, 
          size: 8, 
          font: this.fonts.regular,
          color: isRemise ? COLORS.rougeFabs : COLORS.noir 
        });
        const valW = this.fonts.bold.widthOfTextAtSize(value, 9);
        this.page.drawText(value, { 
          x: PAGE.w - MARGINS.x - valW - 5, 
          y: curY - 13, 
          size: 9, 
          font: this.fonts.bold,
          color: isRemise ? COLORS.rougeFabs : COLORS.noir
        });
        this.page.drawLine({ start: { x, y: curY - 20 }, end: { x: PAGE.w - MARGINS.x, y: curY - 20 }, color: COLORS.grisLigne, thickness: 0.5 });
      }
      curY -= 20;
    };

    row("Montant brut HT", formatFCFA(this.totals.sousTotal));
    
    if (this.totals.remiseLignes) {
      const pct = this.totals.remiseLignesPct ? ` (${this.totals.remiseLignesPct.toFixed(2)} %)` : "";
      row(`Remise sur lignes${pct}`, `- ${formatFCFA(this.totals.remiseLignes)}`);
    }
    
    if (this.totals.remiseGlobale) {
      row(`Remise (${this.totals.remiseGlobalePct} %)`, `- ${formatFCFA(this.totals.remiseGlobale)}`);
    }

    row("NET À PAYER", formatFCFA(this.totals.totalAPayer), true);

    // Montant en lettres (Sur la même ligne que TOTAL À PAYER)
    const letY = curY - 15; // Décalage suffisant pour éviter le chevauchement avec "TOTAL À PAYER"
    const labelLetters = "Arrêtée à la présente facture à la somme de :";
    const labelW = this.fonts.bold.widthOfTextAtSize(labelLetters, 8);
    
    this.page.drawText(labelLetters, { x: MARGINS.x, y: letY - 13, size: 8, font: this.fonts.bold, color: COLORS.noir });
    
    // Montant en lettres en orange et agrandi
    const montantSize = 10;
    this.page.drawText(this.totals.montantLettres, { 
      x: MARGINS.x + labelW + 5, 
      y: letY - 13, 
      size: montantSize, 
      font: this.fonts.bold, 
      color: COLORS.orangeFabs 
    });

    return curY - 20;
  }

  drawSignatures(y: number) {
    const boxW = 150;
    this.page.drawRectangle({
      x: MARGINS.x,
      y: y - 60,
      width: boxW,
      height: 60,
      borderColor: COLORS.grisLigne,
      borderWidth: 0.5,
    });
    this.page.drawText("LA COMPTABILITÉ", { x: MARGINS.x + 5, y: y - 12, size: 8, font: this.fonts.bold });
  }

  async getBytes() {
    return await this.doc.save();
  }

  async getBlob() {
    const bytes = await this.getBytes();
    return new Blob([bytes as any], { type: "application/pdf" });
  }
}
