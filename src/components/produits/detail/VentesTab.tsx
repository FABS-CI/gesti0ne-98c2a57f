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

type Vente = {
  ligne_id: string;
  date_commande: string | null;
  commande_reference: string | null;
  client_nom: string | null;
  statut: string | null;
  quantite: number;
  prix_unitaire: number;
  total_ligne: number;
};

export function VentesTab({ ventes }: { ventes: Vente[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Ventes récentes</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Commande</TableHead>
              <TableHead>Client</TableHead>
              <TableHead>Statut</TableHead>
              <TableHead className="text-right">Qté</TableHead>
              <TableHead className="text-right">PU</TableHead>
              <TableHead className="text-right">Total</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {ventes.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground">
                  Aucune vente
                </TableCell>
              </TableRow>
            ) : (
              ventes.map((v) => (
                <TableRow key={v.ligne_id}>
                  <TableCell>{frDate(v.date_commande)}</TableCell>
                  <TableCell className="font-mono text-xs">{v.commande_reference ?? "—"}</TableCell>
                  <TableCell>{v.client_nom ?? "—"}</TableCell>
                  <TableCell className="capitalize">{v.statut ?? "—"}</TableCell>
                  <TableCell className="text-right">{v.quantite}</TableCell>
                  <TableCell className="text-right">{formatFCFA(v.prix_unitaire)}</TableCell>
                  <TableCell className="text-right">{formatFCFA(v.total_ligne)}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
