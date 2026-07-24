import { z } from "zod";

export const retourLigneSchema = z.object({
  produit_id: z.string().min(1, "Sélectionnez un produit"),
  reference_produit: z.string().nullable().optional(),
  designation: z.string().min(1, "Désignation requise"),
  quantite: z.number().int().min(1, "Quantité ≥ 1"),
  motif: z.string().optional(),
  qte_disponible: z.number().int().optional(),
  prix_unitaire: z.number().optional(),
});

export const retourFormSchema = z
  .object({
    date_retour: z.string().min(1, "Date requise"),
    client_id: z.string().min(1, "Sélectionnez un client"),
    facture_id: z.string().uuid().optional().or(z.literal("")),
    livraison_id: z.string().uuid().optional().or(z.literal("")),
    type_retour: z.enum(["physique", "avoir"]),
    etablissement: z.string().optional(),
    representant_nom: z.string().optional(),
    telephone: z.string().optional(),
    ville: z.string().optional(),
    adresse: z.string().optional(),
    observations: z.string().optional(),
    depot_id: z.string().optional(),
    niveau_urgence: z.enum(["normal", "urgent", "critique"]).optional(),
    motif: z.string().optional(),
    lignes: z.array(retourLigneSchema).min(1, "Ajoutez au moins une ligne produit"),
  })
  .superRefine((val, ctx) => {
    // Pas de doublons de produit
    const ids = val.lignes.map((l) => l.produit_id).filter(Boolean);
    const seen = new Set<string>();
    ids.forEach((id, i) => {
      if (seen.has(id)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["lignes", i, "produit_id"],
          message: "Ce produit est déjà présent dans une autre ligne",
        });
      }
      seen.add(id);
    });
    // Quantité ≤ disponible (quand rattaché à une facture)
    val.lignes.forEach((l, i) => {
      if (l.qte_disponible !== undefined && l.quantite > l.qte_disponible) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["lignes", i, "quantite"],
          message: `Quantité > disponible (${l.qte_disponible})`,
        });
      }
    });
  });

export type RetourFormValues = z.infer<typeof retourFormSchema>;
