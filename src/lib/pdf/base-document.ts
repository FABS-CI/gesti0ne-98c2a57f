
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
  orangeFabs: rgb(0.96, 0.486, 0.0), // #F57C00
  grisClair: rgb(0.968, 0.968, 0.968), // #F7F7F7
  orangeZebra: rgb(1, 0.953, 0.878), // #FFF3E0 (Orange très clair pour zebra)
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
        font: this.fonts.bold, // Passé en gras pour plus de netteté
        color: COLORS.noir,    // Noir profond au lieu de gris/orange
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
      color: COLORS.bleuFabs, // Remplacé orange par bleu officiel FABS
    });

    // Cartouche (D) - Déplacé un peu vers la droite pour éviter chevauchement si titre long
    const cartX = PAGE.w - MARGINS.x - 110;
    const cartY = yTop;
    
    const isStatement = this.data.type === "Relevé de Compte";

    // Bloc bleu de référence : supprimé définitivement pour le Relevé de Compte
    if (!isStatement) {
      const refText =
        this.data.reference.includes('-') ||
        this.data.reference.includes('_') ||
        /^[A-Z]{2,3}$/.test(this.data.reference)
          ? `N° ${this.data.reference}`
          : this.data.reference;
      this.page.drawRectangle({
        x: cartX,
        y: cartY - 18,
        width: 110,
        height: 18,
        color: COLORS.bleuFabs,
      });
      const refW = this.fonts.bold.widthOfTextAtSize(refText, 9);
      this.page.drawText(refText, {
        x: cartX + (110 - refW) / 2,
        y: cartY - 12,
        size: 9,
        font: this.fonts.bold,
        color: COLORS.blanc,
      });
    }

    const details = [
      { l: "Date", v: this.data.date.includes('T') ? this.data.date.split('T')[0].split('-').reverse().join('/') : this.data.date },
      { l: "Heure", v: this.data.heure ?? new Date().toLocaleTimeString("fr-FR", { hour: '2-digit', minute: '2-digit' }) },
    ];

    // Sans le cartouche de référence, on remonte la date/heure pour éviter tout vide
    const detailsTop = isStatement ? cartY - 8 : cartY - 32;

    details.forEach((d, i) => {
      const y = detailsTop - i * 11;
      this.page.drawText(`${d.l} :`, { x: cartX + 15, y, size: 8, font: this.fonts.regular, color: COLORS.noir });
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
      let headerX = x + (col.width - txtW) / 2;
      if (col.key === 'designation' || col.key === 'code') {
        headerX = x + 5;
      } else if (col.key !== 'num' && col.key !== 'qte' && col.key !== 'remisePct') {
        headerX = x + col.width - txtW - 5;
      }
      
      this.page.drawText(txt, {
        x: headerX,
        y: y - 13,
        size: 8,
        font: this.fonts.bold,
        color: COLORS.blanc,
      });

      // Suppression des traits verticaux du header pour un style moderne épuré
      /*
      const headerLineX = Math.round(x * 100) / 100;
      this.page.drawLine({
        start: { x: headerLineX, y: y },
        end: { x: headerLineX, y: y - 20 },
        color: COLORS.grisLigne,
        thickness: 0.5,
      });
      */

      x += col.width;
    });

    // Suppression du dernier trait vertical à droite du header
      /*
    const lastHeaderX = Math.round(x * 100) / 100;
    this.page.drawLine({
      start: { x: lastHeaderX, y },
      end: { x: lastHeaderX, y: y - 20 },
      color: COLORS.grisLigne,
      thickness: 0.5,
    });
    */

    // Lignes
    let curY = y - 20;
    const fontSize = 10;
    const colHPadding = 5;

    lignes.forEach((l, i) => {
      // 1. Calculer la hauteur nécessaire pour cette ligne (rowH)
      let maxRowH = 22;
      const wrapResults = new Map<string, string[]>();

      colonnes.forEach(col => {
        let val = (l as any)[col.key];
        if (typeof val === 'number' && col.key !== 'num' && col.key !== 'qte' && col.key !== 'remisePct') {
          val = formatFCFA(val, false);
        } else if (col.key === 'remisePct' && val) {
          val = `${val} %`;
        }
        val = String(val ?? "");
        
        const availableW = col.width - colHPadding * 2;
        const wrapped = this.wrapText(val, availableW, fontSize);
        wrapResults.set(col.key, wrapped);
        
        const lineH = fontSize * 1.2;
        const textH = wrapped.length * lineH;
        const neededH = textH + 8; // padding vertical
        if (neededH > maxRowH) maxRowH = neededH;
      });

      // 2. Vérifier saut de page
      if (curY - maxRowH < MARGINS.bottom + 50) {
        this.addNewPage();
        curY = PAGE.h - 120;
      }
      
      const rowH = maxRowH;

      // 3. Dessiner le fond (Zebra)
      if (i % 2 === 1) {
        this.page.drawRectangle({ 
          x: MARGINS.x, 
          y: curY - rowH, 
          width: CONTENT_W, 
          height: rowH, 
          color: COLORS.orangeZebra
        });
      }

      // 4. Dessiner le contenu des colonnes
      let curX = MARGINS.x;
      colonnes.forEach(col => {
        const wrapped = wrapResults.get(col.key) || [];
        const lineH = fontSize * 1.2;
        const colHPadding = 5; // On s'assure que le padding est constant
        
        wrapped.forEach((lineText, lineIdx) => {
          const txtW = this.fonts.regular.widthOfTextAtSize(lineText, fontSize);
          
          let alignX = curX + colHPadding;
          if (col.key === 'qte' || col.key === 'num' || col.key === 'remisePct') {
            alignX = curX + (col.width - txtW) / 2;
          } else if (col.key !== 'designation' && col.key !== 'code') {
            // Montant et PU à droite
            alignX = curX + col.width - txtW - colHPadding;
          }
          
          this.page.drawText(lineText, {
            x: alignX,
            y: curY - 15 - (lineIdx * lineH),
            size: fontSize,
            font: this.fonts.regular,
            color: (col.key === 'remisePct') ? COLORS.rougeFabs : COLORS.noir,
          });
        });

        curX += col.width;
      });

      // Trait horizontal sous la ligne
      this.page.drawLine({
        start: { x: MARGINS.x, y: curY - rowH },
        end: { x: MARGINS.x + CONTENT_W, y: curY - rowH },
        color: COLORS.grisLigne,
        thickness: 0.5,
      });

      curY -= rowH;
    });

    return curY;
  }

  // Helper pour le retour à la ligne
  wrapText(text: string, maxWidth: number, fontSize: number): string[] {
    if (!text) return [""];
    const words = text.split(/\s+/);
    const lines: string[] = [];
    let currentLine = '';

    for (const word of words) {
      const testLine = currentLine ? `${currentLine} ${word}` : word;
      const testWidth = this.fonts.regular.widthOfTextAtSize(testLine, fontSize);
      if (testWidth > maxWidth && currentLine) {
        lines.push(currentLine);
        currentLine = word;
      } else {
        currentLine = testLine;
      }
    }
    if (currentLine) lines.push(currentLine);
    return lines;
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

    // Suppression des bordures verticales du bloc des totaux pour le style épuré
    // On dessine une ligne horizontale plus visible avant les totaux
    const drawTotalBoxBorders = (height: number) => {
      // Uniquement la ligne du haut pour séparer du tableau
      this.page.drawLine({ start: { x, y }, end: { x: PAGE.w - MARGINS.x, y }, color: COLORS.grisLigne, thickness: 1 });
    };

    let totalRows = 1; // Montant brut HT
    if (this.totals.remiseLignes) totalRows++;
    if (this.totals.remiseGlobale) totalRows++;
    if (this.totals.tva) totalRows++;
    if (this.totals.frais) totalRows++;
    totalRows++; // Total à payer

    drawTotalBoxBorders(totalRows * 20);


    const row = (label: string, value: string, isTotal = false, isNet = false) => {
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

        // Suppression du trait vertical de séparation dans les totaux
        /*
        const labelColWidth = 110;
        this.page.drawLine({
          start: { x: Math.round((x + labelColWidth) * 100) / 100, y: curY },
          end: { x: Math.round((x + labelColWidth) * 100) / 100, y: curY - 20 },
          color: COLORS.grisLigne,
          thickness: 0.5,
        });
        */

        // Suppression de la ligne horizontale sous chaque ligne de total intermédiaire (style épuré)
        // this.page.drawLine({ start: { x, y: curY - 20 }, end: { x: PAGE.w - MARGINS.x, y: curY - 20 }, color: COLORS.grisLigne, thickness: 0.5 });
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

    const netLabel = this.data.type === "Bon de Réception" ? "MONTANT NET" : "NET À PAYER";
    row(netLabel, formatFCFA(this.totals.totalAPayer), true, true);

    // Montant en lettres avec retour automatique à la ligne
    let letY = curY - 25;
    const labelLetters = "Arrêtée à la présente facture à la somme de :";
    
    // On calcule la largeur disponible pour le montant en lettres
    // La phrase complète "Label : Montant" doit tenir dans CONTENT_W
    const fullText = `${labelLetters} ${this.totals.montantLettres}`;
    const fontSize = 10;
    
    // wrapText utilise CONTENT_W (largeur totale imprimable)
    const wrappedLines = this.wrapText(fullText, CONTENT_W, fontSize);
    
    wrappedLines.forEach((line, idx) => {
      // Pour la première ligne, on peut mettre le label en gras si on veut, 
      // mais le plus simple et propre est de tout mettre dans le même style
      // ou de gérer le gras par segment si on veut vraiment du "Label (gras) : Montant (regular)"
      
      this.page.drawText(line, {
        x: MARGINS.x,
        y: letY - (idx * (fontSize * 1.3)),
        size: fontSize,
        font: this.fonts.bold,
        color: COLORS.noir
      });
    });

    // On ajuste curY selon le nombre de lignes utilisées
    curY = letY - (wrappedLines.length * (fontSize * 1.3)) - 10;


    return curY;
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
