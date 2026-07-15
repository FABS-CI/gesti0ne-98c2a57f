import { z } from "zod";

export const livraisonSchema = z.object({
  livreurNom: z.string().trim().min(1, "Nom du livreur requis"),
  livreurTel: z
    .string()
    .trim()
    .min(1, "Téléphone requis")
    .regex(/^[+0-9 .-]{6,}$/, "Téléphone invalide"),
  vehicule: z.string().trim().min(1, "Véhicule requis"),
  villeLivraison: z.string().trim().min(1, "Ville requise"),
  commune: z.string().trim().min(1, "Commune requise"),
});

export const expeditionSchema = z.object({
  gareDepart: z.string().trim().optional().default(""),
  villeDest: z.string().trim().min(1, "Ville de destination requise"),
  gareResp: z.string().trim().optional().default(""),
  gareTel: z
    .string()
    .trim()
    .optional()
    .refine((v) => !v || /^[+0-9 .-]{6,}$/.test(v), "Téléphone invalide"),
});

export type ColisageFieldErrors = Record<string, string | undefined>;

export function zodToErrors(err: z.ZodError): ColisageFieldErrors {
  const out: ColisageFieldErrors = {};
  for (const issue of err.issues) {
    const key = issue.path.join(".");
    if (!out[key]) out[key] = issue.message;
  }
  return out;
}
