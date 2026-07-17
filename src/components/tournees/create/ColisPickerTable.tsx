import { Loader2 } from "lucide-react";
import { Checkbox } from "@/components/ui/checkbox";
import type { ColisRow, CommandeRow } from "./types";

export function ColisPickerTable({
  rows,
  loading,
  selected,
  toggle,
  clientByCmd,
  depotById,
}: {
  rows: ColisRow[];
  loading: boolean;
  selected: Set<string>;
  toggle: (id: string) => void;
  clientByCmd: Map<string, CommandeRow>;
  depotById: Map<string, string>;
}) {
  if (loading) {
    return (
      <div className="flex items-center justify-center py-10 text-muted-foreground">
        <Loader2 className="h-4 w-4 animate-spin mr-2" /> Chargement…
      </div>
    );
  }
  if (rows.length === 0) {
    return (
      <div className="py-10 text-center text-sm text-muted-foreground">
        Aucun colis prêt non affecté. Préparez un colisage d'abord.
      </div>
    );
  }
  return (
    <div className="overflow-auto max-h-[60vh] border-t">
      <table className="w-full text-xs">
        <thead className="bg-muted/50 sticky top-0">
          <tr>
            <th className="p-2 w-8"></th>
            <th className="p-2 text-left">N° colis</th>
            <th className="p-2 text-left">Commande</th>
            <th className="p-2 text-left">Client</th>
            <th className="p-2 text-left">Représentant</th>
            <th className="p-2 text-left">Ville</th>
            <th className="p-2 text-right">Cartons</th>
            <th className="p-2 text-right">Qté</th>
            <th className="p-2 text-left">Date prép.</th>
            <th className="p-2 text-left">Magasin</th>
            <th className="p-2 text-left">Responsable</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((c) => {
            const cli = c.commande_id ? clientByCmd.get(c.commande_id) : undefined;
            const isSel = selected.has(c.colis_id);
            const rep = cli?.representant_nom ?? cli?.commercial_nom ?? "—";
            const depotNom = cli?.depot_id ? (depotById.get(cli.depot_id) ?? "—") : "—";
            const ville = c.ville_livraison ?? cli?.ville ?? "—";
            return (
              <tr
                key={c.colis_id}
                className={`border-t hover:bg-accent/40 cursor-pointer ${isSel ? "bg-accent/30" : ""}`}
                onClick={() => toggle(c.colis_id)}
              >
                <td className="p-2" onClick={(e) => e.stopPropagation()}>
                  <Checkbox checked={isSel} onCheckedChange={() => toggle(c.colis_id)} />
                </td>
                <td className="p-2 font-mono">{c.reference ?? "—"}</td>
                <td className="p-2 font-mono">{cli?.reference ?? "—"}</td>
                <td className="p-2">{cli?.client_nom ?? "—"}</td>
                <td className="p-2">{rep}</td>
                <td className="p-2">{ville}</td>
                <td className="p-2 text-right">1</td>
                <td className="p-2 text-right">{cli?.total_quantite ?? "—"}</td>
                <td className="p-2">{c.date_colisage ? c.date_colisage.slice(0, 10) : "—"}</td>
                <td className="p-2">{depotNom}</td>
                <td className="p-2">{c.responsable_nom ?? "—"}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
