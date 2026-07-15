import { Badge } from "@/components/ui/badge";
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

type Facture = {
  facture_id: string;
  reference: string;
  date_facture: string | null;
  montant_total: number | string;
  montant_paye: number | string;
  solde: number | string;
  statut: string;
};

type Props = {
  clientNom: string;
  factures: Facture[];
  loading: boolean;
  factureId: string | null;
  onSelect: (f: Facture) => void;
};

function frDate(d: string | null | undefined) {
  return d ? new Date(d).toLocaleDateString("fr-FR") : "—";
}

export function FacturesImpayeesCard({ clientNom, factures, loading, factureId, onSelect }: Props) {
  const soldeTotal = factures.reduce((s, f) => s + Number(f.solde), 0);
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between text-base">
          <span>2. Factures du client {clientNom}</span>
          <span className="text-sm font-normal text-muted-foreground">
            Solde total dû :{" "}
            <span className="font-semibold text-red-600">{formatFCFA(soldeTotal)}</span>
          </span>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-12"></TableHead>
              <TableHead>Référence</TableHead>
              <TableHead>Date</TableHead>
              <TableHead className="text-right">Total</TableHead>
              <TableHead className="text-right">Payé</TableHead>
              <TableHead className="text-right">Solde</TableHead>
              <TableHead>Statut</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="py-6 text-center text-muted-foreground">
                  Chargement…
                </TableCell>
              </TableRow>
            ) : factures.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="py-6 text-center text-muted-foreground">
                  Aucune facture impayée pour ce client
                </TableCell>
              </TableRow>
            ) : (
              factures.map((f) => (
                <TableRow
                  key={f.facture_id}
                  className={factureId === f.facture_id ? "bg-primary/10" : ""}
                >
                  <TableCell>
                    <input
                      type="radio"
                      name="facture"
                      checked={factureId === f.facture_id}
                      onChange={() => onSelect(f)}
                    />
                  </TableCell>
                  <TableCell className="font-mono text-xs">{f.reference}</TableCell>
                  <TableCell>{frDate(f.date_facture)}</TableCell>
                  <TableCell className="text-right">
                    {formatFCFA(Number(f.montant_total))}
                  </TableCell>
                  <TableCell className="text-right text-emerald-600">
                    {formatFCFA(Number(f.montant_paye))}
                  </TableCell>
                  <TableCell className="text-right font-semibold text-red-600">
                    {formatFCFA(Number(f.solde))}
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">
                      {f.statut === "partielle" ? "Partielle" : "Impayée"}
                    </Badge>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
