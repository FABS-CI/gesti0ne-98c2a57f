import type { ReactNode } from "react";
import { Checkbox } from "@/components/ui/checkbox";
import type { ColisRow, CommandeRow } from "./types";

export function ColisTable({
  rows,
  clientByCmd,
  actionHeader,
  selected,
  onToggle,
  emptyLabel,
  actionIcon,
}: {
  rows: ColisRow[];
  clientByCmd: Map<string, CommandeRow>;
  actionHeader: string;
  selected: Set<string>;
  onToggle: (id: string) => void;
  emptyLabel: string;
  actionIcon?: ReactNode;
}) {
  if (rows.length === 0) {
    return <div className="py-8 text-center text-sm text-muted-foreground">{emptyLabel}</div>;
  }
  return (
    <div className="overflow-auto max-h-[45vh] border-t">
      <table className="w-full text-xs">
        <thead className="bg-muted/50 sticky top-0">
          <tr>
            <th className="p-2 w-16 text-left">{actionHeader}</th>
            <th className="p-2 text-left">Réf.</th>
            <th className="p-2 text-left">Client</th>
            <th className="p-2 text-left">Destinataire / Ville</th>
            <th className="p-2 text-left">Livreur</th>
            <th className="p-2 text-right">Cartons</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((c) => {
            const cli = c.commande_id ? clientByCmd.get(c.commande_id) : undefined;
            const isSel = selected.has(c.colis_id);
            return (
              <tr
                key={c.colis_id}
                className={`border-t hover:bg-accent/40 cursor-pointer ${isSel ? "bg-accent/30" : ""}`}
                onClick={() => onToggle(c.colis_id)}
              >
                <td className="p-2" onClick={(e) => e.stopPropagation()}>
                  <div className="flex items-center gap-1">
                    <Checkbox checked={isSel} onCheckedChange={() => onToggle(c.colis_id)} />
                    {actionIcon}
                  </div>
                </td>
                <td className="p-2 font-mono">{c.reference ?? "—"}</td>
                <td className="p-2">{cli?.client_nom ?? "—"}</td>
                <td className="p-2">
                  <div>{c.destinataire ?? "—"}</div>
                  <div className="text-muted-foreground">
                    {[c.ville_livraison, c.quartier].filter(Boolean).join(" · ") || "—"}
                  </div>
                </td>
                <td className="p-2">{c.livreur_nom ?? "—"}</td>
                <td className="p-2 text-right">1</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
