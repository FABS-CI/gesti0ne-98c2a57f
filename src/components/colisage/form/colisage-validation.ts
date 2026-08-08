import { z } from "zod";

export const livraisonSchema = z.object({
  // Champs de livraison supprimés (gérés dans le module Tournées)
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
