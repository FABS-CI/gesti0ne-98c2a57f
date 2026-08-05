import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import {
  invalidateCommande,
  invalidateFacture,
  invalidatePaiement,
  invalidateRetour,
  invalidateStock,
  invalidateClient,
  invalidateColisage,
  invalidateDashboards,
} from "@/lib/cache-invalidation";

type Row = Record<string, unknown> & { id?: string; client_id?: string; facture_id?: string; commande_id?: string; bl_id?: string };

/**
 * Bus temps réel global — Lot 1 perf.
 *
 * Abonne l'application aux `postgres_changes` sur les tables opérationnelles
 * et invalide les caches React Query correspondants. Résultat : listes
 * ventes / stock / livraison / paiements se rafraîchissent automatiquement
 * dès qu'un autre utilisateur (ou un trigger serveur) modifie la donnée,
 * sans F5.
 *
 * - Un seul canal partagé pour toute l'application (coût Realtime minimal).
 * - Debounce implicite : React Query déduplique les invalidations proches.
 * - Filtres RLS s'appliquent (chaque user ne reçoit que ce qu'il peut lire).
 *
 * À monter une seule fois (voir `AppShell`).
 */
export function useRealtimeBus() {
  const qc = useQueryClient();

  useEffect(() => {
    if (typeof window === "undefined") return;

    const channel = supabase.channel("app-realtime-bus");

    const on = (
      table: string,
      handler: (row: Row, eventType: "INSERT" | "UPDATE" | "DELETE") => void,
    ) => {
      channel.on(
        "postgres_changes",
        { event: "*", schema: "public", table },
        (payload) => {
          const row = (payload.new ?? payload.old ?? {}) as Row;
          try {
            handler(row, payload.eventType as "INSERT" | "UPDATE" | "DELETE");
          } catch {
            /* ignore : monitoring ne doit jamais casser l'UI */
          }
        },
      );
    };

    on("commandes", (r) =>
      invalidateCommande(qc, { commandeId: r.id, clientId: r.client_id }),
    );
    on("factures", (r, evt) => {
      invalidateFacture(qc, { factureId: r.id, clientId: r.client_id });
      if (r.statut === "avoir" && evt === "INSERT") {
        toast.message(`Nouvel avoir ${r.reference || ""}`, {
          description: "Le compte client et le stock ont été impactés.",
        });
      }
    });
    on("paiements", (r) =>
      invalidatePaiement(qc, {
        paiementId: r.id,
        factureId: r.facture_id,
        clientId: r.client_id,
      }),
    );
    on("retours", (r, evt) => {
      invalidateRetour(qc, { clientId: r.client_id });
      // Un retour impacte l'avoir client : stock, compta et relevé sont déjà
      // invalidés par invalidateRetour → on prévient discrètement l'utilisateur.
      const ref = typeof r.reference === "string" ? r.reference : null;
      if (evt === "INSERT") {
        toast.message(ref ? `Nouveau retour ${ref}` : "Nouveau retour enregistré", {
          description: "Stock et compte client mis à jour.",
        });
      } else if (evt === "UPDATE") {
        const statut = typeof r.statut === "string" ? r.statut : null;
        toast.message(ref ? `Retour ${ref} mis à jour` : "Retour mis à jour", {
          description: statut ? `Statut : ${statut}` : undefined,
        });
      }
    });
    on("stock_mouvements", () => invalidateStock(qc));
    on("stocks_depots", () => invalidateStock(qc));
    on("produits", () => invalidateStock(qc));
    on("clients", (r) => invalidateClient(qc, r.id));
    on("bons_livraison", (r) => invalidateColisage(qc, { blId: r.id, clientId: r.client_id }));
    on("colis", (r) => invalidateColisage(qc, { blId: r.bl_id, clientId: r.client_id }));
    on("tournees", () => {
      qc.invalidateQueries({ queryKey: ["tournees"] });
      qc.invalidateQueries({ queryKey: ["tournee"] });
      invalidateDashboards(qc);
    });
    on("livraisons", () => {
      qc.invalidateQueries({ queryKey: ["livraisons"] });
      qc.invalidateQueries({ queryKey: ["livraisons-commande"] });
    });
    on("livsuivi_commandes", () => {
      qc.invalidateQueries({ queryKey: ["livsuivi"] });
      qc.invalidateQueries({ queryKey: ["livsuivi-commandes"] });
    });
    on("proformas", (r, evt) => {
      qc.invalidateQueries({ queryKey: ["proformas"] });
      if (r.proforma_id) qc.invalidateQueries({ queryKey: ["proforma", r.proforma_id] });
      
      const ref = typeof r.reference === "string" ? r.reference : null;
      if (evt === "INSERT") {
        toast.message(ref ? `Nouvelle proforma ${ref}` : "Nouvelle proforma enregistrée");
      }
    });

    channel.subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [qc]);
}
