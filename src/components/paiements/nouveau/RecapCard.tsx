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
import { computeRecap } from "@/lib/paiement-recap";

type Props = {
  reference: string;
  solde: number;
  montant: number;
  mode: "draft" | "confirm";
};

export function RecapCard({ reference, solde, montant, mode }: Props) {
  const rec = computeRecap(reference, solde, montant);
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          4. Récapitulatif {mode === "confirm" ? "(à confirmer)" : "(brouillon)"}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Facture</TableHead>
              <TableHead className="text-right">Reste avant</TableHead>
              <TableHead className="text-right">Montant imputé</TableHead>
              <TableHead className="text-right">Reste après</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow>
              <TableCell className="font-mono text-xs">{rec.reference}</TableCell>
              <TableCell className="text-right">{formatFCFA(rec.reste_avant)}</TableCell>
              <TableCell className="text-right font-semibold text-primary">
                {formatFCFA(rec.montant_impute)}
              </TableCell>
              <TableCell className="text-right font-semibold">
                {formatFCFA(rec.reste_apres)}
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
