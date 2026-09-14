import { ensureCertificationFn } from "./certification.functions";

export type AutoCertification = {
  certified: boolean;
  certification_id: string | null;
  canonical_hash: string | null;
  version: number | null;
  certified_at: string | null;
  statut: string | null;
};

/** Un document est-il éligible à la certification automatique (FAC / PRO / BC) ? */
export function isCertifiable(reference: string): boolean {
  const prefix = (reference ?? "").split("-")[0]?.toUpperCase() ?? "";
  return ["FAC", "FC", "PRO", "PF", "CMD", "BC"].includes(prefix);
}

/**
 * Certification automatique idempotente : appelée à la validation d'un document
 * et juste avant la génération de son PDF. Ne lève jamais d'erreur bloquante.
 */
export async function ensureCertificationSafe(
  reference: string,
): Promise<AutoCertification | null> {
  if (!reference || !isCertifiable(reference)) return null;
  try {
    const res = await ensureCertificationFn({ data: { reference } });
    return res as AutoCertification;
  } catch (e) {
    console.error("Certification automatique impossible", e);
    return null;
  }
}

/** Statut technique actif d'une certification (valeur backend historique : AUTHENTIC). */
export function isCertificationActive(statut?: string | null): boolean {
  return statut === "ACTIVE" || statut === "AUTHENTIC";
}
