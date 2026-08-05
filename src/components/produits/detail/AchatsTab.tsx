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

type Achat = {
  achat_id: string;
  date_achat: string | null;
  reference: string;
  libelle: string;
  fournisseur: string | null;
  statut: string;
  montant: number; // total achat
  quantite: number; // qty for this product
  prix_unitaire: number; // unit price for this product
};

export function AchatsTab({ achats }: { achats: Achat[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Achats liés au produit</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Référence</TableHead>
              <TableHead>Libellé</TableHead>
              <TableHead>Fournisseur</TableHead>
              <TableHead className="text-right">Qté</TableHead>
              <TableHead className="text-right">Prix Unit.</TableHead>
              <TableHead className="text-right">Total Achat</TableHead>
              <TableHead>Statut</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {achats.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} className="text-center text-muted-foreground">
                  Aucun achat lié
                </TableCell>
              </TableRow>
            ) : (
              achats.map((a) => (
                <TableRow key={a.achat_id}>
                  <TableCell>{frDate(a.date_achat)}</TableCell>
                  <TableCell className="font-mono text-xs">{a.reference}</TableCell>
                  <TableCell>{a.libelle}</TableCell>
                  <TableCell>{a.fournisseur ?? "—"}</TableCell>
                  <TableCell className="text-right font-medium">{a.quantite}</TableCell>
                  <TableCell className="text-right">{formatFCFA(a.prix_unitaire)}</TableCell>
                  <TableCell className="text-right font-semibold">{formatFCFA(a.montant)}</TableCell>
                  <TableCell className="capitalize">{a.statut}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
