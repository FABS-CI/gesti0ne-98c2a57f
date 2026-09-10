/**
 * Canonicalisation déterministe des documents commerciaux.
 * Le même document produit TOUJOURS exactement la même chaîne, quel que soit
 * l'ordre des clés renvoyé par la base : c'est la base du hash SHA-256.
 */

export type CanonicalLigne = {
  designation: string;
  quantite: number;
  prix_unitaire: number;
  total_ligne: number;
};

export type CanonicalDocument = {
  type: string;
  reference: string;
  date: string;
  client_nom: string;
  montant_total: number;
  lignes: CanonicalLigne[];
};

function num(v: unknown): number {
  const n = Number(v ?? 0);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : 0;
}

function str(v: unknown): string {
  return String(v ?? "").trim();
}

/** Normalise un document brut en structure canonique stable. */
export function toCanonical(input: {
  type: string;
  reference: unknown;
  date: unknown;
  client_nom: unknown;
  montant_total: unknown;
  lignes?: Array<Record<string, unknown>> | null;
}): CanonicalDocument {
  const lignes = (input.lignes ?? []).map((l) => ({
    designation: str(l.designation),
    quantite: num(l.quantite),
    prix_unitaire: num(l.prix_unitaire),
    total_ligne: num(l.total_ligne ?? l.total_ht_ligne),
  }));

  // Tri déterministe : désignation puis montant
  lignes.sort((a, b) =>
    a.designation === b.designation
      ? a.total_ligne - b.total_ligne
      : a.designation.localeCompare(b.designation),
  );

  return {
    type: str(input.type).toUpperCase(),
    reference: str(input.reference).toUpperCase(),
    date: str(input.date).slice(0, 10),
    client_nom: str(input.client_nom),
    montant_total: num(input.montant_total),
    lignes,
  };
}

/** Sérialisation canonique : clés triées, pas d'espaces superflus. */
export function canonicalString(doc: CanonicalDocument): string {
  const sortKeys = (value: unknown): unknown => {
    if (Array.isArray(value)) return value.map(sortKeys);
    if (value && typeof value === "object") {
      const src = value as Record<string, unknown>;
      const out: Record<string, unknown> = {};
      for (const k of Object.keys(src).sort()) out[k] = sortKeys(src[k]);
      return out;
    }
    return value;
  };
  return JSON.stringify(sortKeys(doc));
}
