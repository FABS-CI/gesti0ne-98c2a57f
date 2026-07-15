import { Loader2 } from "lucide-react";
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
import type { DeclLigne, DeclTotaux } from "@/lib/paie-declarations-helpers";

type Props = {
  periode: string;
  isLoading: boolean;
  lignes: DeclLigne[];
  totaux: DeclTotaux;
};

export function DeclarationsTable({ periode, isLoading, lignes, totaux }: Props) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {periode ? `Récapitulatif — ${periode}` : "Récapitulatif"}
        </CardTitle>
      </CardHeader>
      <CardContent>
        {!periode ? (
          <p className="text-sm text-muted-foreground">
            Sélectionnez une période pour afficher la synthèse.
          </p>
        ) : isLoading ? (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" /> Chargement…
          </div>
        ) : lignes.length === 0 ? (
          <p className="text-sm text-muted-foreground">Aucun bulletin pour cette période.</p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Employé</TableHead>
                <TableHead className="text-right">Brut</TableHead>
                <TableHead className="text-right">CNPS Sal.</TableHead>
                <TableHead className="text-right">CNPS Patr.</TableHead>
                <TableHead className="text-right">ITS</TableHead>
                <TableHead className="text-right">CN</TableHead>
                <TableHead className="text-right">CMU</TableHead>
                <TableHead className="text-right">Net</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {lignes.map((l, i) => (
                <TableRow key={i}>
                  <TableCell>{l.employe}</TableCell>
                  <TableCell className="text-right">{formatFCFA(l.brut)}</TableCell>
                  <TableCell className="text-right">{formatFCFA(l.cnpsSalarie)}</TableCell>
                  <TableCell className="text-right">{formatFCFA(l.cnpsPatronal)}</TableCell>
                  <TableCell className="text-right">{formatFCFA(l.its)}</TableCell>
                  <TableCell className="text-right">{formatFCFA(l.cn)}</TableCell>
                  <TableCell className="text-right">
                    {formatFCFA(l.cmuSalarie + l.cmuPatronal)}
                  </TableCell>
                  <TableCell className="text-right">{formatFCFA(l.net)}</TableCell>
                </TableRow>
              ))}
              <TableRow className="font-semibold bg-muted/40">
                <TableCell>TOTAUX</TableCell>
                <TableCell className="text-right">{formatFCFA(totaux.brut)}</TableCell>
                <TableCell className="text-right">{formatFCFA(totaux.cnpsSalarie)}</TableCell>
                <TableCell className="text-right">{formatFCFA(totaux.cnpsPatronal)}</TableCell>
                <TableCell className="text-right">{formatFCFA(totaux.its)}</TableCell>
                <TableCell className="text-right">{formatFCFA(totaux.cn)}</TableCell>
                <TableCell className="text-right">
                  {formatFCFA(totaux.cmuSalarie + totaux.cmuPatronal)}
                </TableCell>
                <TableCell className="text-right">{formatFCFA(totaux.net)}</TableCell>
              </TableRow>
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  );
}
