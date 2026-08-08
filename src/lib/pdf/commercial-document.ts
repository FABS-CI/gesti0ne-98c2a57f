
import { BaseDocument, COLORS, MARGINS, PAGE, CONTENT_W, type DocLigne } from "./base-document";
import { formatFCFA } from "@/lib/format";
import { rgb } from "pdf-lib";

export class CommercialDocument extends BaseDocument {
  discountMode: 'A' | 'B' | 'NONE' = 'NONE';

  setDiscountMode(mode: 'A' | 'B' | 'NONE') {
    this.discountMode = mode;
  }

  // Surcharge du Header pour ajouter le bandeau orange sous le titre
  drawHeader() {
    super.drawHeader();
    
    const yTop = PAGE.h - 25;
    const sepY = yTop - 70;
    
    // Bandeau orange sous l'en-tête (Spécificité FABS-CI)
    this.page.drawLine({
      start: { x: MARGINS.x, y: sepY },
      end: { x: PAGE.w - MARGINS.x, y: sepY },
      thickness: 1.5,
      color: COLORS.orangeFabs,
    });
  }

  async drawContent() {
    let y = PAGE.h - 110;
    
    // Infos Client & QR
    y = await this.drawClientAndQr(y);
    
    // Tableau
    const isBL = this.data.type === 'Bon de Livraison';
    const colonnes = [
      { label: "N°", key: "num", width: 20 },
      { label: "Code", key: "code", width: 55 },
      { label: "Désignation", key: "designation", width: isBL ? 415 : 180 },
      { label: "Qté", key: "qte", width: 30 },
    ];
    
    if (!isBL) {
      colonnes.push({ label: "P.U.", key: "pu", width: 75 });
      if (this.discountMode === 'A') {
        colonnes.push({ label: "Remise (%)", key: "remisePct", width: 55 });
      }
      // Le montant prend le reste exact de l'espace disponible (CONTENT_W)
      const currentWidth = colonnes.reduce((acc, c) => acc + c.width, 0);
      colonnes.push({ label: "Montant", key: "total", width: CONTENT_W - currentWidth });
    }
    
    // Conversion des lignes
    const lignes = (this.data as any).lignes?.map((l: any, i: number) => ({
      num: i + 1,
      code: l.codeArticle ?? l.code ?? "",
      designation: l.designation ?? l.reference ?? "",
      qte: l.qte ?? 0,
      pu: l.prixUnitaire ?? l.pu ?? 0,
      remisePct: l.remisePct ?? 0,
      total: l.montant ?? l.total ?? 0,
    })) || [];

    y = this.drawTable(y, colonnes, lignes);
    
    // Si des remises globales existent, on les affiche en rouge dans le tableau de totaux
    // (Déjà géré dans base-document.ts par la recherche du mot 'remise' dans le label)
    
    // Vérifier si les totaux tiennent sur la page
    if (y < 200) {
      this.addNewPage();
      y = PAGE.h - 110;
    }
    
    // Totaux - Uniquement si ce n'est pas un BL
    if (!isBL) {
      y = this.drawTotals(y);
    }
    
    // Montant impayé retiré à la demande de l'utilisateur
    // if (this.data.type === 'Facture' && (this.data as any).soldeDu > 0) {
    //   y = this.drawImpaye(y, (this.data as any).soldeDu);
    // }
    
    // Signatures
    this.drawSignatures(y);
  }

  drawImpaye(y: number, montant: number): number {
    const boxW = 200;
    const x = PAGE.w - MARGINS.x - boxW;
    
    this.page.drawRectangle({
      x,
      y: y - 25,
      width: boxW,
      height: 25,
      color: COLORS.grisClair,
      borderColor: COLORS.rougeFabs,
      borderWidth: 1,
    });
    
    this.page.drawText("TOTAL IMPAYÉ (FCFA)", {
      x: x + 5,
      y: y - 18,
      size: 9,
      font: this.fonts.bold,
      color: COLORS.rougeFabs,
    });
    
    const val = formatFCFA(montant);
    const valW = this.fonts.bold.widthOfTextAtSize(val, 10);
    this.page.drawText(val, {
      x: PAGE.w - MARGINS.x - valW - 5,
      y: y - 18,
      size: 10,
      font: this.fonts.bold,
      color: COLORS.rougeFabs,
    });
    
    return y - 35;
  }

  drawSignatures(y: number) {
    const yBot = 180; // Position fixe en bas ou relative ?
    // L'utilisateur veut des zones Client + Livreur si c'est un BL
    
    const boxW = (CONTENT_W - 20) / 2;
    const boxH = 60;
    const curY = Math.max(y - 80, 150);
    
    // Zone signatures conditionnelle
    if (this.data.type === 'Bon de Livraison') {
      // Signature 1 : Le Livreur
      this.page.drawRectangle({
        x: MARGINS.x,
        y: curY - boxH,
        width: boxW,
        height: boxH,
        borderColor: COLORS.grisLigne,
        borderWidth: 0.5,
      });
      this.page.drawText("LE LIVREUR", { x: MARGINS.x + 5, y: curY - 15, size: 8, font: this.fonts.bold });
      this.page.drawText("Nom : ....................................", { x: MARGINS.x + 5, y: curY - 30, size: 7, font: this.fonts.regular });
      this.page.drawText("Signature :", { x: MARGINS.x + 5, y: curY - 50, size: 7, font: this.fonts.italic });

      // Signature 2 : Le Client
      this.page.drawRectangle({
        x: PAGE.w - MARGINS.x - boxW,
        y: curY - boxH,
        width: boxW,
        height: boxH,
        borderColor: COLORS.grisLigne,
        borderWidth: 0.5,
      });
      this.page.drawText("RÉCEPTION CLIENT", { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 15, size: 8, font: this.fonts.bold });
      this.page.drawText("Nom : ....................................", { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 30, size: 7, font: this.fonts.regular });
      this.page.drawText("Signature & Cachet :", { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 50, size: 7, font: this.fonts.italic });
    } else if (this.data.type === 'Facture' || this.data.type === 'Proforma' || this.data.type === 'Commande') {
      // Bloc signature déplacé en bas à droite et renommé en LA COMPTABILITÉ
      this.page.drawRectangle({
        x: PAGE.w - MARGINS.x - boxW,
        y: curY - boxH,
        width: boxW,
        height: boxH,
        borderColor: COLORS.grisLigne,
        borderWidth: 0.5,
      });
      this.page.drawText("LA COMPTABILITÉ", { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 15, size: 8, font: this.fonts.bold });
    }
  }
}
