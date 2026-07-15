import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { frDate } from "@/lib/produit-detail-helpers";

type Inventaire = {
  inventaire_id: string;
  date_inventaire: string | null;
  reference: string;
  produit_nom: string;
  stock_theorique: number;
  stock_compte: number;
  ecart: number;
  statut: string;
};

export function InventairesTab({ inventaires }: { inventaires: Inventaire[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Inventaires</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Référence</TableHead>
              <TableHead>Produit</TableHead>
              <TableHead className="text-right">Théorique</TableHead>
              <TableHead className="text-right">Compté</TableHead>
              <TableHead className="text-right">Écart</TableHead>
              <TableHead>Statut</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {inventaires.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center text-muted-foreground">
                  Aucun inventaire
                </TableCell>
              </TableRow>
            ) : (
              inventaires.map((i) => (
                <TableRow key={i.inventaire_id}>
                  <TableCell>{frDate(i.date_inventaire)}</TableCell>
                  <TableCell className="font-mono text-xs">{i.reference}</TableCell>
                  <TableCell>{i.produit_nom}</TableCell>
                  <TableCell className="text-right">{i.stock_theorique}</TableCell>
                  <TableCell className="text-right">{i.stock_compte}</TableCell>
                  <TableCell
                    className={
                      i.ecart !== 0 ? "text-right font-semibold text-destructive" : "text-right"
                    }
                  >
                    {i.ecart}
                  </TableCell>
                  <TableCell className="capitalize">{i.statut}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
