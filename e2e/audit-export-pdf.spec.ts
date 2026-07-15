import { test, expect } from "./fixtures/base";
import { hasAuthSession } from "./fixtures/supabase";
import { readFileSync } from "node:fs";
import { expectFlakyMobile } from "./fixtures/retry";
import { extractPdfPages, headerSequencesPerPage, diffSequence } from "./fixtures/pdf";

// Vérifie l'export PDF de la liste des utilisateurs connectés (§audit)
// - le bouton PDF déclenche un téléchargement
// - le fichier commence par %PDF-
// - le flux texte contient le titre + les colonnes attendues
test.describe("Journal d'audit — export PDF connectés + pagination", () => {
  test.skip(!hasAuthSession, "Lovable-injected Supabase session required");

  test("bouton PDF génère un fichier valide avec colonnes attendues", async ({
    page,
    baseURL,
  }, testInfo) => {
    const isMobile = testInfo.project.name === "mobile";
    // Attache screenshot UNIQUEMENT en mobile (les artefacts trace/vidéo
    // globaux sont déjà uploadés en CI pour les deux projets).
    const snap = async (name: string) => {
      if (!isMobile) return;
      await testInfo.attach(name, {
        body: await page.screenshot(),
        contentType: "image/png",
      });
    };

    const base = baseURL ?? "http://localhost:8080";
    await page.goto(`${base}/audit`, { waitUntil: "domcontentloaded" });

    // Onglet "Connectés"
    await page.getByRole("tab", { name: /Connectés/i }).click();
    await expectFlakyMobile(testInfo, "onglet Connectés chargé", async () => {
      await expect(page.getByRole("button", { name: /PDF/i })).toBeVisible({
      timeout: 10_000,
    });
    });

    // 1. Parcours de toutes les pages AVANT export : capture des emails par page.
    const collectPageEmails = async () =>
      (await page.locator("table tbody tr td:first-child").allInnerTexts())
        .map((s) => s.trim())
        .filter(Boolean);

    const nextBtn = page
      .getByRole("button", { name: /suivant|›|>/i })
      .or(page.locator("button:has(svg.lucide-chevron-right)"))
      .first();

    // Nombre de pages attendu, lu depuis le paginator "Page X / Y" si présent.
    const paginatorText = await page
      .locator('text=/Page\\s+\\d+\\s*\\/\\s*\\d+/')
      .first()
      .textContent()
      .catch(() => null);
    const expectedPageCount = paginatorText
      ? Number(paginatorText.match(/\/\s*(\d+)/)?.[1] ?? 1)
      : 1;

    const pagesEmails: string[][] = [];
    pagesEmails.push(await collectPageEmails());
    await snap("connectes-page-1-avant.png");

    let pageIdx = 1;
    const MAX_PAGES = 20; // borne défensive
    while (pageIdx < MAX_PAGES) {
      const visible = await nextBtn.isVisible().catch(() => false);
      if (!visible) break;
      const disabled = await nextBtn.isDisabled().catch(() => true);
      if (disabled) break;
      await nextBtn.click();
      await page.waitForTimeout(300);
      pageIdx += 1;
      pagesEmails.push(await collectPageEmails());
      await snap(`connectes-page-${pageIdx}-apres.png`);
    }

    // Cohérence loop ↔ paginator : si le paginator annonce N pages, on doit
    // les avoir toutes visitées avant que "suivant" ne se désactive.
    if (expectedPageCount > 1) {
      expect(pageIdx, "paginator ↔ boucle de pages").toBe(expectedPageCount);
    }

    // Retour page 1 pour lancer l'export (les listes clients paginent, le PDF exporte tout)
    const prevBtn = page
      .getByRole("button", { name: /précédent|‹|</i })
      .or(page.locator("button:has(svg.lucide-chevron-left)"))
      .first();
    while (
      (await prevBtn.isVisible().catch(() => false)) &&
      !(await prevBtn.isDisabled().catch(() => true))
    ) {
      await prevBtn.click();
      await page.waitForTimeout(150);
    }

    // 2. Téléchargement — parfois flaky sur mobile (webkit + download event).
    let buf!: Buffer;
    await expectFlakyMobile(testInfo, "téléchargement PDF", async () => {
      const [download] = await Promise.all([
        page.waitForEvent("download", { timeout: 15_000 }),
        page.getByRole("button", { name: /PDF/i }).click(),
      ]);
      const path = await download.path();
      expect(path).toBeTruthy();
      buf = readFileSync(path!);
      expect(buf.length).toBeGreaterThan(1000);
    });

    // Sauvegarde du PDF téléchargé dans les artefacts CI.
    await testInfo.attach("utilisateurs-connectes.pdf", {
      body: buf,
      contentType: "application/pdf",
    });

    expect(buf.length).toBeGreaterThan(1000);
    expect(buf.subarray(0, 5).toString("utf8")).toBe("%PDF-");

    // 3. Extraction texte — flaky selon le sous-set jsPDF ; on retente sur mobile.
    let text = "";
    await expectFlakyMobile(testInfo, "extraction texte PDF", async () => {
      text = buf.toString("latin1");
      expect(text.toLowerCase()).toContain("utilisateurs connect");
    });

    const cols = ["Utilisateur", "Dernière action", "Il y a (min)", "Adresse IP", "Actions"];

    // 3.b — En-têtes vérifiés PAGE PAR PAGE via pdfjs (regroupement Y/X).
    let pdfPages: Awaited<ReturnType<typeof extractPdfPages>> = [];
    await expectFlakyMobile(testInfo, "parse pdfjs multi-pages", async () => {
      pdfPages = await extractPdfPages(buf);
      expect(pdfPages.length).toBeGreaterThan(0);
    });
    const perPage = headerSequencesPerPage(pdfPages, cols);
    await testInfo.attach("pdf-headers-per-page.json", {
      body: Buffer.from(JSON.stringify(perPage, null, 2)),
      contentType: "application/json",
    });
    perPage.forEach((seq, i) => {
      if (seq.length === 0) {
        // autotable ne répète les headers que sur les pages contenant des lignes ;
        // on tolère l'absence si la page est vide.
        return;
      }
      const diff = diffSequence(cols, seq);
      expect(
        seq,
        `PDF page ${i + 1} — en-têtes attendus vs reçus:\n${diff}`,
      ).toEqual(cols);
    });

    // 4. Séquence GLOBALE : jusqu'à 3 emails/page, ordre strict page1..pageN,
    //    avec diff attendu vs reçu si la séquence est cassée.
    const expectedSeq = pagesEmails.flatMap((emails) => emails.slice(0, 3));
    const actualSeq: string[] = [];
    let cursor = -1;
    for (const email of expectedSeq) {
      const pos = text.indexOf(email, cursor + 1);
      if (pos <= cursor) {
        actualSeq.push(`<manquant après pos ${cursor}>`);
      } else {
        actualSeq.push(email);
        cursor = pos;
      }
    }
    if (actualSeq.join("|") !== expectedSeq.join("|")) {
      const diff = diffSequence(expectedSeq, actualSeq);
      await testInfo.attach("sequence-diff.txt", {
        body: Buffer.from(diff),
        contentType: "text/plain",
      });
      expect(actualSeq, `Séquence PDF divergente :\n${diff}`).toEqual(expectedSeq);
    }

    await testInfo.attach("pages-emails.json", {
      body: Buffer.from(JSON.stringify(pagesEmails, null, 2)),
      contentType: "application/json",
    });
  });
});