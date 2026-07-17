import { supabase } from "@/integrations/supabase/client";
import type { Commande } from "@/lib/commandes-api";

/**
 * Chaînage du cycle de vente :
 * Proforma → Commande → Bon de livraison → Facture
 * Toutes les conversions multi-tables passent par des RPC PostgreSQL
 * atomiques (transactions), ce qui garantit qu'un échec en cours annule
 * intégralement l'opération (pas de données à moitié créées).
 */


/** Convertit une proforma en commande via RPC atomique. */
export async function createCommandeFromProforma(proformaId: string): Promise<Commande> {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("proformas.convertir_en_commande");
  const { data: commandeId, error } = await supabase.rpc("convertir_proforma_en_commande", {
    _proforma_id: proformaId,
  } as never);
  if (error) throw new Error(error.message);

  const { data, error: eGet } = await supabase
    .from("commandes")
    .select("*")
    .eq("commande_id", commandeId as unknown as string)
    .single();
  if (eGet) throw eGet;
  return data as Commande;
}

export type ColisageInput = {
  nb_colis: number;
  poids_total?: number | null;
  dimensions?: string | null;
  transporteur?: string | null;
  adresse_livraison?: string | null;
  signataire?: string | null;
  date_livraison?: string | null;
  decrementer_stock?: boolean;
};

/**
 * Conversion Commande → BL + colisage + mouvements stock via RPC atomique.
 * Toutes les écritures (bon de livraison, ordre de colisage, colis, sorties
 * de stock, statut commande) se font dans une même transaction serveur.
 */
export async function convertirCommandeEnBL(commande: Commande, colisage: ColisageInput) {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("commandes.convertir_en_bl");
  const { data, error } = await supabase.rpc("convertir_commande_en_bl", {
    _commande_id: commande.commande_id,
    _nb_colis: colisage.nb_colis,
    _poids_total: colisage.poids_total ?? null,
    _transporteur: colisage.transporteur ?? null,
    _adresse_livraison: colisage.adresse_livraison ?? null,
    _signataire: colisage.signataire ?? null,
    _date_livraison: colisage.date_livraison ?? null,
    _decrementer_stock: colisage.decrementer_stock !== false,
  } as never);
  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : data;
  return row as { bl_id: string; reference: string };
}

/**
 * Crée la facture définitive à partir d'une commande.
 *
 * Lot B : l'insertion directe est supprimée pour éviter les doublons.
 * On délègue à la RPC atomique `valider_commande` qui gère en une seule
 * transaction : contrôle stock, décrément stock, création facture, création BL.
 * Si la commande a déjà une facture non annulée, elle est renvoyée telle quelle.
 */
export async function createFactureFromCommande(commande: Commande) {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("commandes.generer_facture");

  const { data: existing } = await supabase
    .from("factures")
    .select("facture_id, reference")
    .eq("commande_id", commande.commande_id)
    .neq("statut", "annulee")
    .limit(1);
  if (existing && existing.length > 0) {
    return existing[0];
  }

  const { data, error } = await supabase.rpc("valider_commande", {
    _commande_id: commande.commande_id,
  });
  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : data;
  return { reference: (row as { facture_reference?: string })?.facture_reference ?? "" };
}

/**
 * Valide une commande (rôle requis) :
 * - passe la commande au statut "validee"
 * - crée la facture définitive
 * - crée le bon de livraison
 * Tout est fait de manière atomique côté DB via la fonction `valider_commande`.
 */
export async function validerCommande(commandeId: string) {
  const { data, error } = await supabase.rpc("valider_commande", {
    _commande_id: commandeId,
  });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  return row as { facture_reference: string; bl_reference: string };
}
