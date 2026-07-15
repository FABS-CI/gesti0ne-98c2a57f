import { useEffect } from "react";

/**
 * Ctrl/Cmd+S declenche onSave. Empeche l'action navigateur.
 * Ctrl/Cmd+Shift+S declenche onSaveAndContinue si fourni.
 */
export function useSaveHotkey(
  onSave: () => void,
  options?: { onSaveAndContinue?: () => void; enabled?: boolean },
) {
  const { onSaveAndContinue, enabled = true } = options ?? {};
  useEffect(() => {
    if (!enabled) return;
    function handler(e: KeyboardEvent) {
      const meta = e.metaKey || e.ctrlKey;
      if (!meta) return;
      if (e.key.toLowerCase() !== "s") return;
      e.preventDefault();
      if (e.shiftKey && onSaveAndContinue) onSaveAndContinue();
      else onSave();
    }
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onSave, onSaveAndContinue, enabled]);
}
