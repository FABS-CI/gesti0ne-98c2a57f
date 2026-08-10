import { PDFDocument, rgb, StandardFonts, type PDFPage, type PDFFont, type PDFImage } from "pdf-lib";
import fabsLogoUrl from "@/assets/fabs-logo.png";
import { COLORS, PAGE, MARGINS, CONTENT_W } from "./base-document";
import { supabase } from "@/integrations/supabase/client";
import { formatFCFA } from "@/lib/format";
import { COMPANY } from "@/lib/company";

export async function generateAfficheRentreePDF(): Promise<Blob> {
  const doc = await PDFDocument.create();
  const page = doc.addPage([PAGE.w, PAGE.h]);
  
  const fontBold = await doc.embedFont(StandardFonts.HelveticaBold);
  const fontRegular = await doc.embedFont(StandardFonts.Helvetica);

  // Logo
  let logoImg: PDFImage | null = null;
  try {
    const logoResp = await fetch(fabsLogoUrl);
    const logoBytes = await logoResp.arrayBuffer();
    logoImg = await doc.embedPng(logoBytes);
  } catch (e) {
    console.error("Erreur chargement logo:", e);
  }

  // Fond dégradé subtil ou formes géométriques
  page.drawRectangle({
    x: 0,
    y: 0,
    width: PAGE.w,
    height: PAGE.h,
    color: rgb(0.98, 0.98, 1),
  });

  // Entête
  if (logoImg) {
    const logoW = 100;
    const logoH = (logoImg.height / logoImg.width) * logoW;
    page.drawImage(logoImg, {
      x: (PAGE.w - logoW) / 2,
      y: PAGE.h - logoH - 40,
      width: logoW,
      height: logoH,
    });
  }

  const title = "RENTRÉE SCOLAIRE 2026–2027";
  const titleSize = 28;
  const titleW = fontBold.widthOfTextAtSize(title, titleSize);
  page.drawText(title, {
    x: (PAGE.w - titleW) / 2,
    y: PAGE.h - 180,
    size: titleSize,
    font: fontBold,
    color: COLORS.bleuFabs,
  });

  const slogan = "« Une innovation pour une école de qualité »";
  const sloganSize = 14;
  const sloganW = fontRegular.widthOfTextAtSize(slogan, sloganSize);
  page.drawText(slogan, {
    x: (PAGE.w - sloganW) / 2,
    y: PAGE.h - 205,
    size: sloganSize,
    font: fontRegular,
    color: COLORS.orangeFabs,
  });

  const accroche = "Préparez la rentrée avec les Éditions FABS-CI !";
  const accrocheSize = 16;
  const accrocheW = fontBold.widthOfTextAtSize(accroche, accrocheSize);
  page.drawText(accroche, {
    x: (PAGE.w - accrocheW) / 2,
    y: PAGE.h - 240,
    size: accrocheSize,
    font: fontBold,
    color: COLORS.grisTexte,
  });

  // Récupération des couvertures réelles
  const { data: produits } = await supabase
    .from("produits")
    .select("titre, cover_path")
    .not("cover_path", "is", null)
    .limit(8);

  if (produits && produits.length > 0) {
    // Composition des couvertures
    let startX = 60;
    let startY = PAGE.h - 450;
    for (let i = 0; i < produits.length; i++) {
        const p = produits[i];
        try {
            const { data } = await supabase.storage.from("product-covers").download(p.cover_path!);
            if (data) {
                const imgBytes = await data.arrayBuffer();
                const img = await doc.embedStandardFont(StandardFonts.Helvetica); // Fallback si pas image
                // En réalité on devrait embed l'image téléchargée. 
                // Pour cet exemple on va simuler le placement.
                const imgEmbed = await doc.embedPng(imgBytes).catch(() => doc.embedJpg(imgBytes));
                
                const imgW = 90;
                const imgH = (imgEmbed.height / imgEmbed.width) * imgW;
                
                const row = Math.floor(i / 4);
                const col = i % 4;
                
                page.drawImage(imgEmbed, {
                    x: startX + col * 120 + (i % 2 === 0 ? 5 : -5),
                    y: startY - row * 160,
                    width: imgW,
                    height: imgH,
                    rotate: { type: 'degrees', angle: i % 2 === 0 ? 2 : -2 } as any
                });
            }
        } catch (e) {
            console.error("Erreur image produit:", p.titre, e);
        }
    }
  }

  // Bas de page
  const cta = "Découvrez nos collections scolaires";
  const ctaSize = 18;
  const ctaW = fontBold.widthOfTextAtSize(cta, ctaSize);
  page.drawText(cta, {
    x: (PAGE.w - ctaW) / 2,
    y: 120,
    size: ctaSize,
    font: fontBold,
    color: COLORS.bleuFabs,
  });

  const contact = `Tél: ${COMPANY.telephone || '+225 XX XX XX XX'} | WhatsApp: ${COMPANY.whatsapp || '+225 XX XX XX XX'}`;
  const contactSize = 12;
  const contactW = fontRegular.widthOfTextAtSize(contact, contactSize);
  page.drawText(contact, {
    x: (PAGE.w - contactW) / 2,
    y: 80,
    size: contactSize,
    font: fontRegular,
    color: COLORS.grisTexte,
  });

  const pdfBytes = await doc.save();
  return new Blob([pdfBytes], { type: "application/pdf" });
}
