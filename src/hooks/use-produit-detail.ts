import { useQuery } from "@tanstack/react-query";
import { getProduit } from "@/lib/produits-api";
import { listMouvements } from "@/lib/stock-api";
import { getStocksParDepot } from "@/lib/depots-api";
import {
  getProduitAchats,
  getProduitInventaires,
  getProduitVentes,
  getProduitStats,
  getStockHistory,
} from "@/lib/produits-360-api";

export function useProduitDetail(produitId: string) {
  const produitQ = useQuery({
    queryKey: ["produit", produitId],
    queryFn: () => getProduit(produitId),
  });
  const produit = produitQ.data;

  const mouvementsQ = useQuery({
    queryKey: ["produit-mouvements", produitId],
    queryFn: () => listMouvements(produitId),
  });
  const ventesQ = useQuery({
    queryKey: ["produit-ventes", produitId],
    queryFn: () => getProduitVentes(produitId),
  });
  const stockCourant = (stocksDepotsQ.data ?? []).reduce((s, sd) => s + Number(sd.quantite || 0), 0);

  const statsQ = useQuery({
    queryKey: ["produit-stats", produitId, produit?.prix_achat, stockCourant],
    queryFn: () => getProduitStats(produitId, produit!.prix_achat, stockCourant),
    enabled: !!produit && stocksDepotsQ.isSuccess,
  });
  const historyQ = useQuery({
    queryKey: ["produit-history", produitId, stockCourant],
    queryFn: () => getStockHistory(produitId, stockCourant, 90),
    enabled: !!produit && stocksDepotsQ.isSuccess,
  });
  const stocksDepotsQ = useQuery({
    queryKey: ["produit-stocks-depots", produitId],
    queryFn: () => getStocksParDepot(produitId),
  });
  const achatsQ = useQuery({
    queryKey: ["produit-achats", produitId],
    queryFn: () => getProduitAchats(produitId),
    enabled: !!produit,
  });
  const inventairesQ = useQuery({
    queryKey: ["produit-inventaires", produitId, produit?.titre, produit?.reference],
    queryFn: () => getProduitInventaires({ titre: produit!.titre, reference: produit!.reference }),
    enabled: !!produit,
  });

  return {
    produit,
    isLoading: produitQ.isLoading,
    mouvements: mouvementsQ.data ?? [],
    ventes: ventesQ.data ?? [],
    stats: statsQ.data,
    history: historyQ.data ?? [],
    stocksDepots: stocksDepotsQ.data ?? [],
    achats: achatsQ.data ?? [],
    inventaires: inventairesQ.data ?? [],
  };
}
