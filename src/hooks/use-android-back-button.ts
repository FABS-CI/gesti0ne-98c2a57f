import { useEffect } from "react";
import { useRouter } from "@tanstack/react-router";
import { useSidebar } from "@/components/ui/sidebar";

/**
 * Gère le bouton retour physique Android (Capacitor).
 * Priorité :
 * 1. Fermer un overlay Radix ouvert (Dialog, Sheet, Drawer, DropdownMenu, Popover)
 *    en simulant Escape — pas besoin de tracker leur état.
 * 2. Fermer le sidebar mobile s'il est ouvert.
 * 3. Sinon, router.history.back() si on peut, sinon laisser Capacitor quitter l'app.
 *
 * Sur le web (pas Capacitor), ne fait rien.
 */
export function useAndroidBackButton() {
  const router = useRouter();
  const { openMobile, setOpenMobile, isMobile } = useSidebar();

  useEffect(() => {
    let cleanup: (() => void) | undefined;
    let cancelled = false;

    (async () => {
      // Import dynamique : évite de charger le plugin sur le web.
      const { Capacitor } = await import("@capacitor/core").catch(() => ({
        Capacitor: null as unknown as { isNativePlatform: () => boolean } | null,
      }));
      if (!Capacitor || !Capacitor.isNativePlatform?.()) return;
      if (cancelled) return;

      const { App } = await import("@capacitor/app");
      const handle = await App.addListener("backButton", ({ canGoBack }) => {
        // 1. Overlay Radix ouvert ? Envoie Escape.
        const openOverlay = document.querySelector(
          '[data-state="open"][role="dialog"], [data-state="open"][role="menu"], [data-state="open"][role="listbox"]',
        );
        if (openOverlay) {
          document.dispatchEvent(
            new KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
          );
          return;
        }

        // 2. Sidebar mobile ouvert ?
        if (isMobile && openMobile) {
          setOpenMobile(false);
          return;
        }

        // 3. Historique navigateur.
        if (canGoBack) {
          router.history.back();
          return;
        }

        // 4. Rien à faire : quitter l'app.
        App.exitApp();
      });

      cleanup = () => handle.remove();
    })();

    return () => {
      cancelled = true;
      cleanup?.();
    };
  }, [router, isMobile, openMobile, setOpenMobile]);
}
