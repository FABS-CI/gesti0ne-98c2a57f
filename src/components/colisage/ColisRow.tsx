import React from "react";
import { TableCell, TableRow } from "@/components/ui/table";

interface ColisRowProps {
  reference_produit: string | null;
  designation: string | null;
  quantite: number;
}

export const ColisRow = React.memo(function ColisRow({
  reference_produit,
  designation,
  quantite,
}: ColisRowProps) {
  return (
    <TableRow>
      <TableCell className="font-mono text-xs">{reference_produit ?? "—"}</TableCell>
      <TableCell>{designation ?? "—"}</TableCell>
      <TableCell className="text-right">{quantite}</TableCell>
    </TableRow>
  );
});
