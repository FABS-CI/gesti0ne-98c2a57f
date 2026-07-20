import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

/**
 * Realtime : invalide toutes les queries de la fiche client (counts, listes,
 * stats, audit) dès qu'une commande, facture, proforma, BL, livraison,
 * paiement ou retour lié au client est créée / modifiée / supprimée.
 *
 * Les changements de `paiements` et `livraisons` sont propagés sans filtre
 * (pas de `client_id` direct sur ces tables) — on invalide et le refetch
 * recalcule via les factures / BL du client.
 */
export function useClientRealtime(clientId: string | undefined) {
  const qc = useQueryClient();
  useEffect(() => {
    if (!clientId) return;
    const invalidate = () => {
      qc.invalidateQueries({ queryKey: ["client", clientId] });
      qc.invalidateQueries({ queryKey: ["client-audit", clientId] });
      qc.invalidateQueries({ queryKey: ["client-report-a-nouveau", clientId] });
    };

    const filter = `client_id=eq.${clientId}`;
    const scoped = ["commandes", "factures", "proformas", "bons_livraison", "retours"] as const;
    const global = ["paiements", "livraisons"] as const;

    const channel = supabase.channel(`client-realtime-${clientId}`);
    scoped.forEach((table) => {
      channel.on(
        "postgres_changes",
        { event: "*", schema: "public", table, filter },
        invalidate,
      );
    });
    global.forEach((table) => {
      channel.on("postgres_changes", { event: "*", schema: "public", table }, invalidate);
    });
    channel.on(
      "postgres_changes",
      { event: "UPDATE", schema: "public", table: "clients", filter: `client_id=eq.${clientId}` },
      invalidate,
    );
    channel.subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [clientId, qc]);
}
