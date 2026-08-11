
import { BaseDocument, COLORS, MARGINS, PAGE, CONTENT_W } from "./base-document";
import { formatFCFA } from "@/lib/format";

export class RetourDocument extends BaseDocument {
  async drawContent() {
    let y = PAGE.h - 110;
    
    // 1. Infos Client (sans QR car RET ne doit pas en avoir selon docTypeConfig)
    y = await this.drawClientSection(y);
    
    // 2. Tableau des articles retournés
    const colonnes = [
      { label: "N°", key: "num", width: 25 },
      { label: "Code", key: "code", width: 70 },
      { label: "Désignation", key: "designation", width: 230 },
      { label: "Quantité retournée", key: "qte", width: 80 },
      { label: "Motif", key: "motif", width: 80 },
      { label: "Observation", key: "obs", width: CONTENT_W - 485 },
    ];
    
    const lignes = (this.data as any).lignes?.map((l: any, i: number) => ({
      num: i + 1,
      code: l.codeArticle ?? l.code ?? "",
      designation: l.designation ?? l.reference ?? "",
      qte: l.qteRetournee ?? l.qte ?? 0,
      motif: l.motif ?? "",
      obs: l.observation ?? "",
    })) || [];

    y = this.drawTable(y, colonnes, lignes);
    
    if (y < 150) {
      this.addNewPage();
      y = PAGE.h - 110;
    }

    // 3. Motif du retour global & Observations si présentes
    if (this.data.notes) {
      y = this.drawSectionTitle(y, "MOTIF ET OBSERVATIONS");
      y = this.drawLongText(y, this.data.notes, 10);
      y -= 10;
    }
    
    // 4. Validation (Demandé par / Approuvé par)
    this.drawValidationSignatures(y);
  }

  async drawClientSection(y: number): Promise<number> {
    const boxH = 80;
    const boxW = CONTENT_W; // Pleine largeur pour le retour
    
    this.page.drawRectangle({
      x: MARGINS.x,
      y: y - boxH,
      width: boxW,
      height: boxH,
      color: COLORS.grisClair,
      opacity: 0.5,
    });

    this.page.drawText("RETOUR DE", { x: MARGINS.x + 10, y: y - 15, size: 7, font: this.fonts.bold, color: COLORS.bleuFabs });
    this.page.drawText((this.data.client.nom || "CLIENT INCONNU").toUpperCase(), { x: MARGINS.x + 10, y: y - 32, size: 12, font: this.fonts.bold, color: COLORS.bleuFabs });
    
    const kv = [
      { l: "Ville", v: this.data.client.ville ?? "—" },
      { l: "Représentant", v: this.data.client.representant ?? "—" },
      { l: "Téléphone", v: this.data.client.telephone ?? "—" },
    ];
    kv.forEach((item, i) => {
      this.page.drawText(`${item.l} :`, { x: MARGINS.x + 10, y: y - 48 - i * 11, size: 8, font: this.fonts.regular });
      this.page.drawText(item.v, { x: MARGINS.x + 80, y: y - 48 - i * 11, size: 8, font: this.fonts.bold });
    });

    return y - boxH - 20;
  }

  drawValidationSignatures(y: number) {
    const boxW = (CONTENT_W - 20) / 2;
    const boxH = 100;
    const curY = Math.max(y - 40, 160);
    
    const demandeur = (this.data as any).demandeur || "—";
    const approuvePar = (this.data as any).approuvePar || "—";
    const dateApprobation = (this.data as any).dateApprobation || "—";

    // Demandeur
    this.page.drawText("VALIDATION", { x: MARGINS.x, y: curY + 15, size: 9, font: this.fonts.bold, color: COLORS.bleuFabs });

    // Bloc Demandeur
    this.page.drawRectangle({
      x: MARGINS.x,
      y: curY - boxH,
      width: boxW,
      height: boxH,
      borderColor: COLORS.grisLigne,
      borderWidth: 0.5,
    });
    this.page.drawText("DEMANDÉ PAR", { x: MARGINS.x + 5, y: curY - 15, size: 8, font: this.fonts.bold });
    this.page.drawText(demandeur, { x: MARGINS.x + 5, y: curY - 30, size: 8, font: this.fonts.regular });
    this.page.drawText("Signature :", { x: MARGINS.x + 5, y: curY - 80, size: 7, font: this.fonts.italic });

    // Bloc Approbation
    this.page.drawRectangle({
      x: PAGE.w - MARGINS.x - boxW,
      y: curY - boxH,
      width: boxW,
      height: boxH,
      borderColor: COLORS.grisLigne,
      borderWidth: 0.5,
    });
    this.page.drawText("APPROUVÉ PAR", { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 15, size: 8, font: this.fonts.bold });
    this.page.drawText(approuvePar, { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 30, size: 8, font: this.fonts.regular });
    this.page.drawText(`Date : ${dateApprobation}`, { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 45, size: 7, font: this.fonts.regular });
    this.page.drawText("Signature & Cachet :", { x: PAGE.w - MARGINS.x - boxW + 5, y: curY - 80, size: 7, font: this.fonts.italic });
  }

  drawSectionTitle(y: number, title: string): number {
    this.page.drawText(title, {
      x: MARGINS.x,
      y: y - 10,
      size: 9,
      font: this.fonts.bold,
      color: COLORS.bleuFabs
    });
    return y - 25;
  }

  drawLongText(y: number, text: string, size: number): number {
    const lines = this.wrapText(text, CONTENT_W, size);
    lines.forEach(line => {
      this.page.drawText(line, {
        x: MARGINS.x,
        y: y,
        size: size,
        font: this.fonts.regular
      });
      y -= (size * 1.2);
    });
    return y;
  }
}
