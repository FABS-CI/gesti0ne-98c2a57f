import React from "react";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { EmptyRow } from "./shared";
import { frDate } from "@/lib/client-detail-helpers";
import { formatFCFA } from "@/lib/format";
import type { ClientRelations } from "@/lib/clients-api";

type Facture = ClientRelations["factures"][number];

const FactureRow = React.memo(function FactureRow({ f }: { f: Facture }) {
  return (
    <TableRow>
      <TableCell className="font-mono text-xs">{f.reference}</TableCell>
      <TableCell>{frDate(f.date_facture)}</TableCell>
      <TableCell>
        <Badge variant="secondary">{f.statut}</Badge>
      </TableCell>
      <TableCell className="text-right">{formatFCFA(f.montant_total)}</TableCell>
      <TableCell className="text-right">{formatFCFA(f.montant_paye)}</TableCell>
    </TableRow>
  );
});

export function ClientFacturesTab({ factures }: { factures: ClientRelations["factures"] }) {
  return (
    <div className="rounded-lg border bg-card">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Référence</TableHead>
            <TableHead>Date</TableHead>
            <TableHead>Statut</TableHead>
            <TableHead className="text-right">Total</TableHead>
            <TableHead className="text-right">Payé</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {!factures.length ? (
            <EmptyRow cols={5} label="Aucune facture" />
          ) : (
            factures.map((f) => <FactureRow key={f.facture_id} f={f} />)
          )}
        </TableBody>
      </Table>
    </div>
  );
}
