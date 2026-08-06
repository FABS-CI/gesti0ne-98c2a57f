import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import {
  getBLDetail,
  listColisForBL,
  annulerColisage,
  supprimerColisage,
  deverrouillerColisage,
} from "@/lib/colisage-api";
import { getParametre } from "@/lib/parametres-api";
import { COMMUNES_ABIDJAN } from "@/lib/ci-locations";
import { invalidateColisage } from "@/lib/cache-invalidation";
import { friendlyError } from "@/lib/friendly-error";

export function useColisageDetail(blId: string) {
  const qc = useQueryClient();
  const navigate = useNavigate();

  const { data: bl, isLoading } = useQuery({
    queryKey: ["bl-detail", blId],
    queryFn: () => getBLDetail(blId),
  });

  const { data: clientInfo } = useQuery({
    queryKey: ["colisage-client-info", bl?.client_id],
    enabled: !!bl?.client_id,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("clients")
        .select("client_id, ville, commune, quartier")
        .eq("client_id", bl!.client_id!)
        .maybeSingle();
      if (error) throw error;
      return data;
    },
  });

  const { data: colisExistants } = useQuery({
    queryKey: ["colis-for-bl", blId],
    queryFn: () => listColisForBL(blId),
  });

  const { data: responsablesList = [] } = useQuery({
    queryKey: ["preparateurs-colisage-actifs"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("preparateurs_colisage")
        .select("preparateur_id, nom, poste, telephone")
        .eq("actif", true)
        .order("nom");
      if (error) throw error;
      return data ?? [];
    },
  });

  const { data: livreursList = [] } = useQuery({
    queryKey: ["livreurs-actifs-colisage"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("livreurs")
        .select("livreur_id, nom_complet, telephone, actif")
        .eq("actif", true)
        .order("nom_complet");
      if (error) throw error;
      return (data ?? []).map((l) => ({
        livreur_id: l.livreur_id,
        nom: l.nom_complet,
        telephone: l.telephone,
        vehicule_defaut: null,
        immatriculation: null,
        societe: null,
      }));
    },
      if (error) throw error;
      return data ?? [];
    },
  });

  const { data: zonesDirectes } = useQuery({
    queryKey: ["param-zones-livraison-directe"],
    queryFn: async () => {
      const raw = await getParametre("colisage.zones_livraison_directe");
      const defaults = {
        villes: ["Abidjan"] as string[],
        communes: COMMUNES_ABIDJAN as string[],
      };
      if (!raw) return defaults;
      try {
        const parsed = JSON.parse(raw) as { villes?: string[]; communes?: string[] };
        return {
          villes: parsed.villes?.length ? parsed.villes : defaults.villes,
          communes: parsed.communes?.length ? parsed.communes : defaults.communes,
        };
      } catch {
        return defaults;
      }
    },
  });

  function invalidateAll() {
    invalidateColisage(qc, { blId, clientId: bl?.client_id ?? undefined });
  }

  const annulerMut = useMutation({
    mutationFn: (motif: string | null) => annulerColisage(blId, motif),
    onSuccess: () => {
      toast.success("Colisage annulé");
      invalidateAll();
    },
    onError: (e: Error) => toast.error(friendlyError(e, "Erreur lors de l'annulation")),
  });

  const supprMut = useMutation({
    mutationFn: (motif: string | null) => supprimerColisage(blId, motif),
    onSuccess: (summary) => {
      const parts = summary
        ? [
            `${summary.colis_supprimes} colis`,
            summary.tournees_recalculees ? `${summary.tournees_recalculees} tournée(s) recalculée(s)` : null,
            summary.livraisons_detachees + summary.livraisons_commande_detachees
              ? `${summary.livraisons_detachees + summary.livraisons_commande_detachees} livraison(s) détachée(s)`
              : null,
            summary.notifications_supprimees ? `${summary.notifications_supprimees} notif.` : null,
          ].filter(Boolean)
        : [];
      toast.success("Colisage supprimé", {
        description: parts.length ? parts.join(" · ") : undefined,
      });
      invalidateAll();
      navigate({ to: "/colisage" });
    },
    onError: (e: Error) => toast.error(friendlyError(e, "Erreur lors de la suppression")),
  });

  const deverMut = useMutation({
    mutationFn: (motif: string) => deverrouillerColisage(blId, motif),
    onSuccess: () => {
      toast.success("Colisage déverrouillé — vous pouvez maintenant le modifier");
      invalidateAll();
    },
    onError: (e: Error) => toast.error(friendlyError(e, "Erreur lors du déverrouillage")),
  });

  return {
    bl,
    isLoading,
    clientInfo,
    colisExistants,
    responsablesList,
    livreursList,
    zonesDirectes,
    annulerMut,
    supprMut,
    deverMut,
  };
}
