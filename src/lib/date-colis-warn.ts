// Helper de validation pour le sélecteur "Date colis" (module Tournées).
// Empêche de préparer une tournée avec une mauvaise date (J+1 / J-1)
// ou de valider quand aucun colis n'a été trouvé pour la date choisie.

export type DateWarnLevel = "ok" | "info" | "warn" | "error";

export type DateColisWarn = {
  level: DateWarnLevel;
  message: string | null;
  /** true si la sélection doit bloquer la validation du formulaire */
  blocking: boolean;
};

export function todayISO(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function diffDays(iso: string): number {
  // renvoie iso - today en jours (négatif si passé)
  const [y, m, d] = iso.split("-").map((x) => Number(x));
  if (!y || !m || !d) return NaN;
  const target = Date.UTC(y, m - 1, d);
  const now = new Date();
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  return Math.round((target - today) / 86_400_000);
}

/**
 * Retourne un avertissement selon l'écart avec aujourd'hui + le nb de colis.
 * - Date invalide ou > 7j / < -7j → bloquant.
 * - J±1 → warning non bloquant (rappel).
 * - Aucun colis trouvé → warning bloquant (rien à préparer).
 */
export function checkDateColis(iso: string, colisCount: number): DateColisWarn {
  if (!iso) {
    return { level: "error", message: "Date colis obligatoire.", blocking: true };
  }
  const delta = diffDays(iso);
  if (Number.isNaN(delta)) {
    return { level: "error", message: "Date colis invalide.", blocking: true };
  }
  if (delta > 7 || delta < -7) {
    return {
      level: "error",
      message: `Écart de ${delta} jours avec aujourd'hui. Vérifiez la date choisie.`,
      blocking: true,
    };
  }
  if (colisCount === 0) {
    return {
      level: "warn",
      message: "Aucun colis prêt trouvé pour cette date. Vérifiez la date ou préparez un colisage.",
      blocking: true,
    };
  }
  if (delta === 1) {
    return {
      level: "warn",
      message: "Date de demain (J+1) — confirmez qu'il s'agit bien d'une tournée anticipée.",
      blocking: false,
    };
  }
  if (delta === -1) {
    return {
      level: "warn",
      message: "Date d'hier (J-1) — confirmez qu'il s'agit d'un rattrapage.",
      blocking: false,
    };
  }
  if (delta !== 0) {
    return {
      level: "info",
      message: `Date J${delta > 0 ? "+" : ""}${delta}.`,
      blocking: false,
    };
  }
  return { level: "ok", message: null, blocking: false };
}
