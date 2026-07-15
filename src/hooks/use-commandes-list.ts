import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { listCommandes, deleteCommande, type Commande } from "@/lib/commandes-api";
import { listClients } from "@/lib/clients-api";
import { listProduits } from "@/lib/produits-api";
import { describeSupabaseError } from "@/lib/rbac-api";
import {
  convertirCommandeEnBL,
  createFactureFromCommande,
  validerCommande,
  type ColisageInput,
} from "@/lib/cycle-vente";
import type { AdvancedFilters } from "@/components/search/AdvancedSearchBar";
import {
  invalidateCommande,
  invalidateColisage,
  invalidateFacture,
} from "@/lib/cache-invalidation";

interface UseCommandesListParams {
  q: string;
  statut: string;
  advanced: AdvancedFilters;
  exerciceId: string | null | undefined;
  page?: number;
  pageSize?: number;
}

export function useCommandesList({
  q,
  statut,
  advanced,
  exerciceId,
  page = 1,
  pageSize = 50,
}: UseCommandesListParams) {
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["commandes", exerciceId, q, statut, advanced, page, pageSize],
    enabled: !!exerciceId,
    queryFn: () =>
      listCommandes({
        q,
        statut: statut === "all" ? undefined : statut,
        ...advanced,
        exerciceId,
        page,
        pageSize,
      }),
    placeholderData: (prev) => prev,
    staleTime: 30_000,
  });

  const { data: clientsData } = useQuery({
    queryKey: ["clients-mini"],
    queryFn: () => listClients({ pageSize: 100, actif: true }),
    staleTime: 5 * 60 * 1000,
    gcTime: 30 * 60 * 1000,
  });

  const { data: produitsData } = useQuery({
    queryKey: ["produits-mini"],
    queryFn: () => listProduits({ pageSize: 200, actif: true }),
    staleTime: 5 * 60 * 1000,
    gcTime: 30 * 60 * 1000,
  });

  const deleteMutation = useMutation({
    mutationFn: ({ id, motif }: { id: string; motif?: string | null }) =>
      deleteCommande(id, motif),
    onSuccess: (summary) => {
      toast.success(
        "Le Bon de Commande a été supprimé définitivement avec toutes les données associées.",
      );
      if (summary && typeof summary === "object") {
        const total = Object.values(summary).reduce(
          (s, v) => s + (typeof v === "number" ? v : 0),
          0,
        );
        if (total > 0) {
          toast.message(`${total} enregistrements liés nettoyés`, {
            description: Object.entries(summary)
              .filter(([, v]) => typeof v === "number" && v > 0)
              .map(([k, v]) => `${k}: ${v}`)
              .join(" · "),
          });
        }
      }
      invalidateCommande(queryClient);
    },
    onError: (e) => {
      const msg = e instanceof Error ? e.message : "Erreur";
      // Le RPC lève "Bon de commande introuvable" (SQLSTATE P0002)
      // quand la commande a déjà été supprimée ailleurs (autre onglet,
      // cache périmé). On rafraîchit la liste et on affiche un message clair.
      if (/introuvable/i.test(msg)) {
        toast.info("Cette commande a déjà été supprimée. La liste est actualisée.");
        invalidateCommande(queryClient);
        return;
      }
      const d = describeSupabaseError(e);
      toast.error(d.title, { description: d.message });
    },
  });

  const blNewMutation = useMutation({
    mutationFn: ({ c, params }: { c: Commande; params: ColisageInput }) =>
      convertirCommandeEnBL(c, params),
    onSuccess: (bl: { reference: string }, vars) => {
      toast.success(`BL ${bl.reference} créé (commande livrée)`);
      invalidateColisage(queryClient, { clientId: vars.c.client_id ?? undefined });
    },
    onError: (e) => {
      const d = describeSupabaseError(e);
      toast.error(d.title, { description: d.message });
    },
  });

  const factureMutation = useMutation({
    mutationFn: (c: Commande) => createFactureFromCommande(c),
    onSuccess: (fac: { reference: string }, c) => {
      toast.success(`Facture ${fac.reference} créée`);
      invalidateFacture(queryClient, { clientId: c.client_id ?? undefined });
    },
    onError: (e) => {
      const d = describeSupabaseError(e);
      toast.error(d.title, { description: d.message });
    },
  });

  const validerMutation = useMutation({
    mutationFn: (id: string) => validerCommande(id),
    onSuccess: (res) => {
      toast.success(
        `Commande validée — Facture ${res.facture_reference} et BL ${res.bl_reference} créés`,
      );
      invalidateColisage(queryClient);
      invalidateFacture(queryClient);
    },
    onError: (e) => {
      const d = describeSupabaseError(e);
      toast.error(d.title, { description: d.message });
    },
  });

  return {
    data,
    isLoading,
    clientsData,
    produitsData,
    deleteMutation,
    blNewMutation,
    factureMutation,
    validerMutation,
  };
}
