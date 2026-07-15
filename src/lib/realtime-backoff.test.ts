import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { BACKOFF_INITIAL, BACKOFF_MAX, nextBackoffDelay } from "./realtime-backoff";

describe("nextBackoffDelay", () => {
  it("double le délai jusqu'au plafond", () => {
    expect(nextBackoffDelay(BACKOFF_INITIAL)).toBe(10000);
    expect(nextBackoffDelay(10000)).toBe(20000);
    expect(nextBackoffDelay(20000)).toBe(40000);
    expect(nextBackoffDelay(40000)).toBe(BACKOFF_MAX);
    expect(nextBackoffDelay(BACKOFF_MAX)).toBe(BACKOFF_MAX);
  });
});

/**
 * Simule la boucle de polling du composant TourneesPage :
 *   - un timer est armé quand rtStatus !== "live" ;
 *   - à chaque tick, le délai est augmenté via nextBackoffDelay ;
 *   - dès que rtStatus repasse à "live", le timer courant est annulé et le
 *     délai retombe à BACKOFF_INITIAL.
 */
function makeBackoffLoop() {
  let delay = BACKOFF_INITIAL;
  let timer: ReturnType<typeof setTimeout> | null = null;
  let ticks = 0;

  const stop = () => {
    if (timer) clearTimeout(timer);
    timer = null;
  };
  const tick = () => {
    ticks += 1;
    delay = nextBackoffDelay(delay);
    timer = setTimeout(tick, delay);
  };

  return {
    setStatus(status: "live" | "error") {
      if (status === "live") {
        stop();
        delay = BACKOFF_INITIAL;
        return;
      }
      stop();
      timer = setTimeout(tick, delay);
    },
    getDelay: () => delay,
    getTicks: () => ticks,
    hasPending: () => timer !== null,
  };
}

describe("boucle de polling Realtime — reset immédiat au retour « live »", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("stoppe le backoff dès que l'abonnement repasse à live", () => {
    const loop = makeBackoffLoop();

    // Passage en erreur : le timer est armé
    loop.setStatus("error");
    expect(loop.hasPending()).toBe(true);

    // Deux ticks : 5s → 10s → 20s
    vi.advanceTimersByTime(5000);
    vi.advanceTimersByTime(10000);
    expect(loop.getTicks()).toBe(2);
    expect(loop.getDelay()).toBe(20000);
    expect(loop.hasPending()).toBe(true);

    // Retour à live : timer annulé, délai réinitialisé
    loop.setStatus("live");
    expect(loop.hasPending()).toBe(false);
    expect(loop.getDelay()).toBe(BACKOFF_INITIAL);

    // Même en avançant le temps, plus aucun tick ne doit se produire.
    vi.advanceTimersByTime(60000);
    expect(loop.getTicks()).toBe(2);
  });

  it("repart de BACKOFF_INITIAL à la coupure suivante", () => {
    const loop = makeBackoffLoop();
    loop.setStatus("error");
    vi.advanceTimersByTime(5000); // 1 tick → délai 10s
    loop.setStatus("live");
    loop.setStatus("error");
    expect(loop.getDelay()).toBe(BACKOFF_INITIAL);
    vi.advanceTimersByTime(5000);
    expect(loop.getDelay()).toBe(10000);
  });
});
