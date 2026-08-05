import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";

export type EntityKey = "produits" | "clients" | "fournisseurs";

export type ImportColumn = {
  /** Clé colonne en base */
  key: string;
  /** Libellé humain */
  label: string;
  required?: boolean;
  /** Aliases d'entête CSV reconnus (insensibles à la casse / accents) */
  aliases?: string[];
};

export type EntityConfig = {
  key: EntityKey;
  table: "produits" | "clients" | "fournisseurs";
  label: string;
  columns: ImportColumn[];
  /** Validation Zod par ligne (post-mapping) */
  validate: (
    row: Record<string, unknown>,
  ) => { ok: true; data: Record<string, unknown> } | { ok: false; errors: string[] };
};

const normalize = (s: string) =>
  s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");

export function autoMapHeaders(
  headers: string[],
  cols: ImportColumn[],
): Record<string, string | null> {
  const map: Record<string, string | null> = {};
  for (const col of cols) {
    const candidates = [col.key, col.label, ...(col.aliases ?? [])].map(normalize);
    const found = headers.find((h) => candidates.includes(normalize(h)));
    map[col.key] = found ?? null;
  }
  return map;
}

const numFromStr = (v: unknown): number | undefined => {
  if (v === null || v === undefined || v === "") return undefined;
  const s = String(v).replace(/\s/g, "").replace(",", ".");
  const n = Number(s);
  return Number.isFinite(n) ? n : NaN;
};
const intFromStr = (v: unknown): number | undefined => {
  const n = numFromStr(v);
  if (n === undefined) return undefined;
  if (!Number.isFinite(n)) return NaN;
  return Math.trunc(n);
};

const produitSchema = z.object({
  titre: z.string().trim().min(1, "titre requis"),
  reference: z.string().trim().optional(),
  isbn: z.string().trim().optional(),
  categorie: z.string().trim().default("manuel"),
  niveau: z.string().trim().optional(),
  matiere: z.string().trim().optional(),
  auteur: z.string().trim().optional(),
  editeur: z.string().trim().optional(),
  prix_vente: z.number().nonnegative().default(0),
  prix_achat: z.number().nonnegative().default(0),
  stock: z.number().int().nonnegative().default(0),
  seuil_alerte: z.number().int().nonnegative().default(10),
});

const clientSchema = z.object({
  nom: z.string().trim().min(1, "nom requis"),
  type_client: z.string().trim().default("autre"),
  email: z.union([z.literal(""), z.string().email("email invalide")]).optional(),
  telephone: z.string().trim().optional(),
  representant: z.string().trim().optional(),
  adresse: z.string().trim().optional(),
  ville: z.string().trim().optional(),
  pays: z.string().trim().optional(),
  nif: z.string().trim().optional(),
  plafond_credit: z.number().nonnegative().default(0),
  delai_paiement: z.number().int().nonnegative().default(0),
});

const fournisseurSchema = z.object({
  raison_sociale: z.string().trim().min(1, "raison sociale requise"),
  representant: z.string().trim().optional(),
  email: z.union([z.literal(""), z.string().email("email invalide")]).optional(),
  telephone: z.string().trim().optional(),
  adresse: z.string().trim().optional(),
  ville: z.string().trim().optional(),
});

function cleanEmpty<T extends Record<string, unknown>>(o: T): T {
  for (const k of Object.keys(o)) {
    if (o[k] === "" || o[k] === undefined) delete (o as Record<string, unknown>)[k];
  }
  return o;
}

function makeValidate<T extends z.ZodTypeAny>(
  schema: T,
  coerce: (row: Record<string, unknown>) => Record<string, unknown>,
): EntityConfig["validate"] {
  return (row) => {
    const coerced = coerce(row);
    const parsed = schema.safeParse(coerced);
    if (!parsed.success) {
      return {
        ok: false,
        errors: parsed.error.issues.map((i) => `${i.path.join(".") || "?"} : ${i.message}`),
      };
    }
    return { ok: true, data: cleanEmpty(parsed.data as Record<string, unknown>) };
  };
}

export const ENTITIES: Record<EntityKey, EntityConfig> = {
  produits: {
    key: "produits",
    table: "produits",
    label: "Produits",
    columns: [
      { key: "titre", label: "Titre", required: true, aliases: ["nom", "designation", "libelle"] },
      { key: "reference", label: "Référence", aliases: ["ref", "code"] },
      { key: "isbn", label: "ISBN" },
      { key: "categorie", label: "Catégorie", aliases: ["category"] },
      { key: "niveau", label: "Niveau" },
      { key: "matiere", label: "Matière" },
      { key: "auteur", label: "Auteur" },
      { key: "editeur", label: "Éditeur" },
      { key: "prix_vente", label: "Prix de vente", aliases: ["prix", "pv"] },
      { key: "prix_achat", label: "Prix d'achat", aliases: ["pa", "cout"] },
      { key: "stock", label: "Stock", aliases: ["quantite", "qte"] },
      { key: "seuil_alerte", label: "Seuil d'alerte", aliases: ["seuil"] },
    ],
    validate: makeValidate(produitSchema, (r) => ({
      ...r,
      prix_vente: numFromStr(r.prix_vente) ?? 0,
      prix_achat: numFromStr(r.prix_achat) ?? 0,
      stock: intFromStr(r.stock) ?? 0,
      seuil_alerte: intFromStr(r.seuil_alerte) ?? 10,
    })),
  },
  clients: {
    key: "clients",
    table: "clients",
    label: "Clients",
    columns: [
      { key: "nom", label: "Nom", required: true, aliases: ["raison_sociale", "client"] },
      { key: "type_client", label: "Type", aliases: ["type"] },
      { key: "email", label: "Email", aliases: ["mail"] },
      { key: "telephone", label: "Téléphone", aliases: ["tel", "phone"] },
      { key: "representant", label: "Représentant" },
      { key: "adresse", label: "Adresse" },
      { key: "ville", label: "Ville" },
      { key: "pays", label: "Pays" },
      { key: "nif", label: "NIF" },
      { key: "plafond_credit", label: "Plafond crédit", aliases: ["plafond"] },
      { key: "delai_paiement", label: "Délai paiement (j)", aliases: ["delai"] },
    ],
    validate: makeValidate(clientSchema, (r) => ({
      ...r,
      plafond_credit: numFromStr(r.plafond_credit) ?? 0,
      delai_paiement: intFromStr(r.delai_paiement) ?? 0,
    })),
  },
  fournisseurs: {
    key: "fournisseurs",
    table: "fournisseurs",
    label: "Fournisseurs",
    columns: [
      {
        key: "raison_sociale",
        label: "Raison sociale",
        required: true,
        aliases: ["nom", "fournisseur"],
      },
      { key: "representant", label: "Représentant" },
      { key: "email", label: "Email", aliases: ["mail"] },
      { key: "telephone", label: "Téléphone", aliases: ["tel"] },
      { key: "adresse", label: "Adresse" },
      { key: "ville", label: "Ville" },
    ],
    validate: makeValidate(fournisseurSchema, (r) => r),
  },
};

export async function insertBatch(entity: EntityKey, rows: Record<string, unknown>[]) {
  if (rows.length === 0) return { inserted: 0 };
  const cfg = ENTITIES[entity];
  const CHUNK = 200;
  let inserted = 0;
  for (let i = 0; i < rows.length; i += CHUNK) {
    const slice = rows.slice(i, i + CHUNK);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error, count } = await (supabase.from(cfg.table) as any).insert(slice, {
      count: "exact",
    });
    if (error) throw new Error(error.message);
    inserted += count ?? slice.length;
  }
  return { inserted };
}

export function buildTemplateCSV(entity: EntityKey): string {
  const cfg = ENTITIES[entity];
  return cfg.columns.map((c) => c.label).join(",") + "\n";
}
