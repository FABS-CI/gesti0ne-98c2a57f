import { z } from "zod";

export const ligneSchema = z.object({
  produit_id: z.string().min(1, "Sélectionnez un produit"),
  reference_produit: z.string().nullable().optional(),
  designation: z.string().min(1, "Désignation requise"),
  stock_dispo: z.number(),
  quantite: z.number().int().min(1, "Quantité ≥ 1"),
});

export const specimenFormSchema = z
  .object({
    date_envoi: z.string().min(1, "Date requise"),
    motif: z.string().optional(),
    donneur_nom: z.string().trim().min(1, "Donneur obligatoire"),
    observations: z.string().optional(),
    depot_id: z.string().optional(),
    client_id: z.string().min(1, "Sélectionnez un client"),
    etablissement: z.string().optional(),
    representant_nom: z.string().optional(),
    telephone: z.string().optional(),
    ville: z.string().optional(),
    adresse: z.string().optional(),
    lignes: z.array(ligneSchema).min(1, "Ajoutez au moins une ligne produit"),
  })
  .superRefine((data, ctx) => {
    data.lignes.forEach((l, i) => {
      if (l.quantite > l.stock_dispo) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["lignes", i, "quantite"],
          message: `Stock insuffisant (dispo: ${l.stock_dispo})`,
        });
      }
    });
  });

export type SpecimenFormValues = z.infer<typeof specimenFormSchema>;
