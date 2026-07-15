import { useEffect } from "react";

/**
 * Gère le clavier virtuel Android (Capacitor Keyboard) :
 * - Mode "resize body" pour que la viewport se raccourcisse quand le clavier apparaît
 *   (les éléments sticky/fixés restent visibles).
 * - Expose --keyboard-height en CSS variable (utile pour padding-bottom dynamique).
 * - Scroll-into-view automatique du champ actif quand le clavier s'ouvre.
 * No-op sur le web.
 */
export function useMobileKeyboard() {
  useEffect(() => {
    let removeShow: (() => void) | undefined;
    let removeHide: (() => void) | undefined;
    let cancelled = false;

    (async () => {
      const { Capacitor } = await import("@capacitor/core").catch(() => ({
        Capacitor: null as unknown as { isNativePlatform: () => boolean } | null,
      }));
      if (!Capacitor?.isNativePlatform?.()) return;
      if (cancelled) return;

      const { Keyboard, KeyboardResize } = await import("@capacitor/keyboard");
      try {
        await Keyboard.setResizeMode({ mode: KeyboardResize.Body });
        await Keyboard.setScroll({ isDisabled: false });
      } catch {
        /* certains devices refusent, on ignore */
      }

      const show = await Keyboard.addListener("keyboardWillShow", (info) => {
        document.documentElement.style.setProperty(
          "--keyboard-height",
          `${info.keyboardHeight}px`,
        );
        // Scroll le champ actif dans la moitié haute visible.
        const el = document.activeElement as HTMLElement | null;
        if (el && "scrollIntoView" in el) {
          requestAnimationFrame(() => {
            el.scrollIntoView({ block: "center", behavior: "smooth" });
          });
        }
      });

      const hide = await Keyboard.addListener("keyboardWillHide", () => {
        document.documentElement.style.setProperty("--keyboard-height", "0px");
      });

      removeShow = () => show.remove();
      removeHide = () => hide.remove();
    })();

    return () => {
      cancelled = true;
      removeShow?.();
      removeHide?.();
    };
  }, []);
}
