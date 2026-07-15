import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatFCFA } from "@/lib/format";
import { frDate } from "@/lib/produit-detail-helpers";
import type { ProduitHistorique } from "@/lib/produits-360-api";

export function HistoriqueTab({ historique }: { historique: ProduitHistorique[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Historique complet</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Référence</TableHead>
              <TableHead>Libellé</TableHead>
              <TableHead className="text-right">Quantité</TableHead>
              <TableHead className="text-right">Montant</TableHead>
              <TableHead>Statut</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {historique.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground">
                  Aucun historique
                </TableCell>
              </TableRow>
            ) : (
              historique.map((h) => (
                <TableRow key={`${h.type}-${h.id}`}>
                  <TableCell>{frDate(h.date)}</TableCell>
                  <TableCell className="capitalize">{h.type}</TableCell>
                  <TableCell className="font-mono text-xs">{h.reference}</TableCell>
                  <TableCell>{h.libelle}</TableCell>
                  <TableCell className="text-right">{h.quantite ?? "—"}</TableCell>
                  <TableCell className="text-right">
                    {h.montant != null ? formatFCFA(h.montant) : "—"}
                  </TableCell>
                  <TableCell className="capitalize">{h.statut ?? "—"}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
