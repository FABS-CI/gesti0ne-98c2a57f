import { useEffect, useState } from "react";

export type IpGeo = {
  city: string | null;
  region: string | null;
  country: string | null;
  country_code: string | null;
  isp: string | null;
  lat: number | null;
  lon: number | null;
};

const cache = new Map<string, IpGeo>();
const inflight = new Map<string, Promise<IpGeo | null>>();

async function fetchOne(ip: string): Promise<IpGeo | null> {
  if (cache.has(ip)) return cache.get(ip)!;
  if (inflight.has(ip)) return inflight.get(ip)!;
  // ipwho.is : gratuit, sans clé, CORS ouvert. Ignore les IP privées.
  if (/^(10\.|127\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.|::1|fc|fd)/i.test(ip)) return null;
  const p = fetch(
    `https://ipwho.is/${encodeURIComponent(ip)}?fields=success,city,region,country,country_code,connection,latitude,longitude`,
  )
    .then((r) => (r.ok ? r.json() : null))
    .then((j) => {
      if (!j || j.success === false) return null;
      const g: IpGeo = {
        city: j.city ?? null,
        region: j.region ?? null,
        country: j.country ?? null,
        country_code: j.country_code ?? null,
        isp: j.connection?.isp ?? null,
        lat: typeof j.latitude === "number" ? j.latitude : null,
        lon: typeof j.longitude === "number" ? j.longitude : null,
      };
      cache.set(ip, g);
      return g;
    })
    .catch(() => null)
    .finally(() => inflight.delete(ip));
  inflight.set(ip, p);
  return p;
}

/** Résout la géolocalisation d'une liste d'IP avec mise en cache mémoire. */
export function useIpGeo(ips: string[]): Record<string, IpGeo> {
  const key = Array.from(new Set(ips.filter(Boolean)))
    .sort()
    .join(",");
  const [map, setMap] = useState<Record<string, IpGeo>>({});

  useEffect(() => {
    let cancelled = false;
    const unique = Array.from(new Set(ips.filter(Boolean)));
    // Seed depuis cache
    const seed: Record<string, IpGeo> = {};
    unique.forEach((ip) => {
      const c = cache.get(ip);
      if (c) seed[ip] = c;
    });
    if (Object.keys(seed).length) setMap((m) => ({ ...m, ...seed }));

    const missing = unique.filter((ip) => !cache.has(ip));
    if (missing.length === 0) return;
    Promise.all(missing.map((ip) => fetchOne(ip).then((g) => [ip, g] as const))).then((res) => {
      if (cancelled) return;
      const next: Record<string, IpGeo> = {};
      res.forEach(([ip, g]) => {
        if (g) next[ip] = g;
      });
      if (Object.keys(next).length) setMap((m) => ({ ...m, ...next }));
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return map;
}
