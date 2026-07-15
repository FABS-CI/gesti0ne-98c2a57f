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

type Mouvement = {
  mouvement_id: string;
  created_at: string | null;
  type: string;
  quantite: number;
  stock_resultant: number;
};

export function MouvementsTab({ mouvements }: { mouvements: Mouvement[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Mouvements de stock</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Type</TableHead>
              <TableHead className="text-right">Quantité</TableHead>
              <TableHead className="text-right">Stock résultant</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {mouvements.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} className="text-center text-muted-foreground">
                  Aucun mouvement
                </TableCell>
              </TableRow>
            ) : (
              mouvements.map((m) => (
                <TableRow key={m.mouvement_id}>
                  <TableCell>{frDate(m.created_at)}</TableCell>
                  <TableCell className="capitalize">{m.type}</TableCell>
                  <TableCell className="text-right">{m.quantite}</TableCell>
                  <TableCell className="text-right">{m.stock_resultant}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
