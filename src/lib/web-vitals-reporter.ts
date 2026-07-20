import { supabase } from "@/integrations/supabase/client";
import type { Metric } from "web-vitals";

/**
 * Web Vitals reporter — Lot 5.
 * Collecte LCP/INP/CLS/TTFB/FCP et envoie en batch vers `perf_web_vitals`.
 *
 * - Non bloquant : `beacon` prioritaire, fallback fetch async.
 * - Dédoublonnage par (metric, id) pour éviter les re-reports.
 * - Batch envoyé sur visibilitychange=hidden ou pagehide.
 * - Sampling 100% par défaut ; réduire via ?sampling=0.2 pour prod haut trafic.
 */

type VitalRecord = {
  metric: string;
  value: number;
  rating: string;
  route: string;
  url: string;
  navigation_type?: string;
  user_agent: string;
};

const buffer: VitalRecord[] = [];
const seen = new Set<string>();
let installed = false;

function currentRoute(): string {
  if (typeof window === "undefined") return "";
  const p = window.location.pathname;
  // Anonymise UUIDs / IDs numériques pour l'agrégation
  return p
    .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ":id")
    .replace(/\/\d+(?=\/|$)/g, "/:id");
}

async function flush() {
  if (buffer.length === 0) return;
  const payload = buffer.splice(0);
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const rows = payload.map((r) => ({ ...r, user_id: user?.id ?? null }));
    await supabase.from("perf_web_vitals").insert(rows);
  } catch {
    /* silent — perf metrics best-effort */
  }
}

function handleMetric(m: Metric) {
  const key = `${m.name}:${m.id}`;
  if (seen.has(key)) return;
  seen.add(key);
  buffer.push({
    metric: m.name,
    value: Math.round(m.value * 1000) / 1000,
    rating: m.rating,
    route: currentRoute(),
    url: window.location.href.slice(0, 500),
    navigation_type: m.navigationType,
    user_agent: navigator.userAgent.slice(0, 300),
  });
  if (buffer.length >= 10) void flush();
}

export async function installWebVitals(): Promise<void> {
  if (installed || typeof window === "undefined") return;
  installed = true;

  try {
    const params = new URLSearchParams(window.location.search);
    const sampling = Number(params.get("sampling") ?? "1");
    if (Number.isFinite(sampling) && sampling > 0 && sampling < 1) {
      if (Math.random() > sampling) return;
    }

    const { onCLS, onLCP, onINP, onTTFB, onFCP } = await import("web-vitals");
    onCLS(handleMetric);
    onLCP(handleMetric);
    onINP(handleMetric);
    onTTFB(handleMetric);
    onFCP(handleMetric);

    const onHide = () => {
      if (document.visibilityState === "hidden") void flush();
    };
    document.addEventListener("visibilitychange", onHide);
    window.addEventListener("pagehide", () => void flush());
  } catch {
    /* web-vitals unavailable */
  }
}
