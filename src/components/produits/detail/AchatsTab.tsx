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
  montant: number;
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
              <TableHead>Statut</TableHead>
              <TableHead className="text-right">Montant</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {achats.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center text-muted-foreground">
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
                  <TableCell className="capitalize">{a.statut}</TableCell>
                  <TableCell className="text-right">{formatFCFA(a.montant)}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
