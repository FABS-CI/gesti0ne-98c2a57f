import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { printEtiquettes } from "./print-etiquettes";

vi.mock("@/assets/fabs-logo.png", () => ({ default: "logo.png" }));

const toastError = vi.fn();
vi.mock("sonner", () => ({ toast: { error: (...a: unknown[]) => toastError(...a) } }));

describe("printEtiquettes", () => {
  beforeEach(() => {
    toastError.mockReset();
  });
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("affiche un toast quand le navigateur bloque la pop-up", () => {
    const spy = vi.spyOn(window, "open").mockReturnValue(null);
    const result = printEtiquettes("<div/>", "T", "a4-one", "preview");
    expect(result).toBeNull();
    expect(toastError).toHaveBeenCalledOnce();
    expect(String(toastError.mock.calls[0][0])).toMatch(/pop-?up/i);
    spy.mockRestore();
  });

  it("mode preview: injecte preview-bar avec boutons Imprimer et Fermer, sans auto-print", () => {
    const doc = { write: vi.fn(), close: vi.fn() };
    const fake = { document: doc } as unknown as Window;
    vi.spyOn(window, "open").mockReturnValue(fake);

    const html =
      '<div class="etiquette-carton" data-colis-id="c1">1 / 2</div>' +
      '<div class="etiquette-carton" data-colis-id="c2">2 / 2</div>';
    const w = printEtiquettes(html, "Aperçu BL", "a4-one", "preview");
    expect(w).toBe(fake);

    const written = doc.write.mock.calls[0][0] as string;
    expect(written).toContain('class="preview-bar"');
    expect(written).toMatch(/<button[^>]*onclick="window\.print\(\)"[^>]*>Imprimer<\/button>/);
    expect(written).toMatch(/<button[^>]*onclick="window\.close\(\)"[^>]*>Fermer<\/button>/);
    // Pas d'auto-print en mode preview
    expect(written).not.toMatch(
      /setTimeout\(function \(\) \{ window\.focus\(\); window\.print\(\); \}/,
    );
    // Pagination x/N préservée pour chaque carton
    expect(written).toContain("1 / 2");
    expect(written).toContain("2 / 2");
    // 1 colis = 1 page A4
    expect(written).toContain("size: A4 portrait");
    expect(written).toMatch(/\.etiquette-carton\s*\{[^}]*page-break-after:\s*always/);
  });

  it("mode print: déclenche window.print automatiquement au chargement", () => {
    const doc = { write: vi.fn(), close: vi.fn() };
    vi.spyOn(window, "open").mockReturnValue({ document: doc } as unknown as Window);
    printEtiquettes("<div/>", "T", "a4-one", "print");
    const written = doc.write.mock.calls[0][0] as string;
    expect(written).toContain("window.print()");
    expect(written).not.toContain('class="preview-bar"');
  });
});
