import React from "react";
import { TableCell, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { STATUT_LABEL, type Commande } from "@/lib/commandes-api";
import { formatFCFA } from "@/lib/format";
import { CommandeActions } from "@/components/commandes/CommandeActions";

interface CommandeRowProps {
  commande: Commande;
  readOnly: boolean;
  isSuperAdmin: boolean;
  canModifier: boolean;
  canValider: boolean;
  onValider: (id: string) => void;
  validerPending: boolean;
  onDelete: (c: Commande) => void;
}

function CommandeRowInner({
  commande: c,
  readOnly,
  isSuperAdmin,
  canModifier,
  canValider,
  onValider,
  validerPending,
  onDelete,
}: CommandeRowProps) {
  const st = STATUT_LABEL[c.statut];
  return (
    <TableRow className="transition-colors hover:bg-muted/50">
      <TableCell className="font-semibold">{c.reference}</TableCell>
      <TableCell>{c.client_nom || "—"}</TableCell>
      <TableCell className="text-muted-foreground">{c.date_commande}</TableCell>
      <TableCell>
        <Badge
          variant="outline"
          className="border-transparent font-medium"
          style={{ background: `${st?.color}1a`, color: st?.color }}
        >
          {st?.label ?? c.statut}
        </Badge>
      </TableCell>
      <TableCell className="text-right font-medium">{formatFCFA(c.montant_total)}</TableCell>
      <TableCell className="text-right">
        <CommandeActions
          commande={c}
          readOnly={readOnly}
          isSuperAdmin={isSuperAdmin}
          canModifier={canModifier}
          canValider={canValider}
          onValider={onValider}
          validerPending={validerPending}
          onDelete={onDelete}
        />
      </TableCell>
    </TableRow>
  );
}

export const CommandeRow = React.memo(CommandeRowInner);
