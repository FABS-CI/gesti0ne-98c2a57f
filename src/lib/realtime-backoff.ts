/**
 * Backoff exponentiel utilisé quand l'abonnement Realtime n'est plus « live ».
 * Progression : 5s → 10s → 20s → 40s → plafond 60s.
 * Le retour à l'état « live » doit réinitialiser à BACKOFF_INITIAL et couper
 * immédiatement le timer en cours (voir `TourneesPage`).
 */
export const BACKOFF_INITIAL = 5000;
export const BACKOFF_MAX = 60000;

export function nextBackoffDelay(current: number): number {
  return Math.min(Math.max(current, BACKOFF_INITIAL) * 2, BACKOFF_MAX);
}
