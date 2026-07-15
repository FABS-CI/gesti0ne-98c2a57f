import { supabase } from "@/integrations/supabase/client";
import type { LivStatut, LivSuiviCommande, LivType } from "./types";

export async function avancerEtape(
  livraisonId: string,
  etape: LivStatut,
  meta: Record<string, string> = {},
  commentaire?: string,
) {
  const { data, error } = await supabase.rpc("livsuivi_avancer", {
    _livraison_id: livraisonId,
    _etape: etape,
    _meta: meta,
    _commentaire: commentaire,
  });
  if (error) throw new Error(error.message);
  return data as unknown as LivSuiviCommande;
}

// creerTournee supprimé : la création d'une tournée passe désormais par le
// module /tournees (table `tournees`) et l'appel RPC `finaliser_tournee`.

/**
 * Valide une tournée : vérifie les champs obligatoires, marque `tournees.statut`
 * comme `en_cours` (validée) et crée les lignes `livsuivi_commandes`
 * correspondantes. C'est cette étape — et non la clôture du colisage — qui
 * fait apparaître les commandes dans le module « Suivi de livraison ».
 */
export async function finaliserTournee(tourneeId: string) {
  const { data, error } = await supabase.rpc("finaliser_tournee" as never, {
    _tournee_id: tourneeId,
  } as never);
  if (error) throw new Error(error.message);
  return data as unknown as { tournee_id: string; statut: string };
}

/**
 * Confirme la réception d'une livraison avec preuves (signature, photo, nom
 * réceptionnaire, tél, commentaire). Passe la livraison à `reception_confirmee`
 * et déclenche automatiquement la clôture de la tournée si toutes ses
 * livraisons sont terminées.
 */
export async function confirmerReception(params: {
  id: string;
  signatureUrl?: string | null;
  photoUrl?: string | null;
  receptionnaireNom?: string | null;
  receptionnaireTel?: string | null;
  commentaire?: string | null;
}) {
  const { data, error } = await supabase.rpc("livsuivi_confirmer_reception" as never, {
    _id: params.id,
    _signature_url: params.signatureUrl ?? null,
    _photo_url: params.photoUrl ?? null,
    _receptionnaire_nom: params.receptionnaireNom ?? null,
    _receptionnaire_tel: params.receptionnaireTel ?? null,
    _commentaire: params.commentaire ?? null,
  } as never);
  if (error) throw new Error(error.message);
  return data as unknown as LivSuiviCommande;
}

/**
 * Upload d'une preuve (signature PNG ou photo JPEG) dans le bucket
 * `livraison-preuves` et renvoie l'URL signée durable (7 jours) à stocker
 * dans `signature_url` / `photo_preuve_url`.
 */
export async function uploadPreuveLivraison(
  livraisonId: string,
  kind: "signature" | "photo",
  file: Blob,
): Promise<string> {
  const ext = kind === "signature" ? "png" : file.type === "image/png" ? "png" : "jpg";
  const path = `${livraisonId}/${kind}-${Date.now()}.${ext}`;
  const { error } = await supabase.storage
    .from("livraison-preuves")
    .upload(path, file, { contentType: file.type || (kind === "signature" ? "image/png" : "image/jpeg"), upsert: true });
  if (error) throw error;
  const { data, error: signErr } = await supabase.storage
    .from("livraison-preuves")
    .createSignedUrl(path, 60 * 60 * 24 * 7);
  if (signErr) throw signErr;
  return data.signedUrl;
}

export async function avancerMasse(
  tourneeId: string,
  etape: LivStatut,
  meta: Record<string, string> = {},
  filtreGare?: string,
) {
  const { data, error } = await supabase.rpc("livsuivi_avancer_masse", {
    _tournee_id: tourneeId,
    _etape: etape,
    _meta: meta,
    _filtre_gare: filtreGare,
  });
  if (error) throw new Error(error.message);
  return (data as number) ?? 0;
}

export async function assignerTournee(livraisonId: string, tourneeId: string, type: LivType) {
  const { error } = await supabase
    .from("livsuivi_commandes")
    .update({ tournee_id: tourneeId, type_livraison: type })
    .eq("id", livraisonId);
  if (error) throw error;
}

export async function updateHistoriqueCommentaire(id: string, commentaire: string) {
  const { error } = await supabase.from("livsuivi_historique").update({ commentaire }).eq("id", id);
  if (error) throw error;
}

export async function deleteHistorique(id: string) {
  const { error } = await supabase.from("livsuivi_historique").delete().eq("id", id);
  if (error) throw error;
}

export type SupprimerLivraisonSuiviSummary = {
  livraison_id: string;
  commande_id: string | null;
  bl_id: string | null;
  motif: string | null;
  historique_supprime: number;
  colis_reinitialises: number;
  livraisons_detachees: number;
  livraisons_commande_detachees: number;
  notifications_supprimees: number;
  role: "super_admin" | "user";
};

export async function deleteLivraisonSuivi(
  id: string,
  motif?: string | null,
): Promise<SupprimerLivraisonSuiviSummary | null> {
  const { data, error } = await supabase.rpc("supprimer_livraison_suivi" as never, {
    _id: id,
    _motif: motif ?? "",
  } as never);
  if (error) throw error;
  return (data as SupprimerLivraisonSuiviSummary | null) ?? null;
}
