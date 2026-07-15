import { z } from "zod";

/**
 * Schéma Zod strict : uniquement des UUID valides pour chaque référentiel.
 * Aucune saisie libre autorisée — toute chaîne non UUID est rejetée.
 */
export const livraisonFormSchema = z.object({
  source_type: z.enum(["colisage", "expedition"]),
  source_id: z.string().uuid("Sélectionne un colisage ou une expédition."),
  transporteur_id: z.string().uuid("Transporteur obligatoire (sélection dans la liste)."),
  livreur_id: z.string().uuid("Livreur obligatoire (sélection dans la liste)."),
  gare_depart_id: z.string().uuid("Gare de départ invalide.").nullable(),
  gare_arrivee_id: z.string().uuid("Gare d'arrivée invalide.").nullable(),
  date_livraison: z.string().min(1, "Date obligatoire."),
  notes: z.string().nullable(),
});

export type LivraisonFormInput = z.infer<typeof livraisonFormSchema>;
