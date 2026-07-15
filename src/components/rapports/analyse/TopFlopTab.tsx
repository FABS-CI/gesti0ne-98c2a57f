import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { TopBarChart } from "@/components/rapports/RapportCharts";
import type { FlopReport, TopProduit } from "@/lib/rapports-api";
import { formatFCFA } from "@/lib/format";

type Props = {
  topN: number;
  onTopN: (n: number) => void;
  top: TopProduit[] | undefined;
  flop: FlopReport | undefined;
};

export function TopFlopTab({ topN, onTopN, top, flop }: Props) {
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <span className="text-sm">Afficher le Top</span>
        <Select value={String(topN)} onValueChange={(v) => onTopN(Number(v))}>
          <SelectTrigger className="w-24">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="10">10</SelectItem>
            <SelectItem value="20">20</SelectItem>
            <SelectItem value="50">50</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Top {topN} produits les plus vendus</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>#</TableHead>
                  <TableHead>Produit</TableHead>
                  <TableHead className="text-right">Qté</TableHead>
                  <TableHead className="text-right">CA</TableHead>
                  <TableHead className="text-right">Clients</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {(top ?? []).map((p, i) => (
                  <TableRow key={p.produit_id}>
                    <TableCell>
                      <Badge variant={i < 3 ? "default" : "secondary"}>{i + 1}</Badge>
                    </TableCell>
                    <TableCell>{p.titre}</TableCell>
                    <TableCell className="text-right font-medium">{p.qte_vendue}</TableCell>
                    <TableCell className="text-right">{formatFCFA(p.ca)}</TableCell>
                    <TableCell className="text-right">{p.nb_clients}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Produits jamais ou peu vendus</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="mb-2 text-sm font-medium">
              Jamais vendus ({flop?.jamais_vendus.length ?? 0})
            </p>
            <div className="max-h-40 overflow-y-auto rounded border">
              <Table>
                <TableBody>
                  {(flop?.jamais_vendus ?? []).slice(0, 50).map((p, i) => (
                    <TableRow key={i}>
                      <TableCell className="font-mono text-xs">{p.code}</TableCell>
                      <TableCell>{p.titre}</TableCell>
                      <TableCell>{p.niveau ?? "—"}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
            <p className="mb-2 mt-3 text-sm font-medium">
              Très peu vendus ({flop?.peu_vendus.length ?? 0})
            </p>
            <div className="max-h-40 overflow-y-auto rounded border">
              <Table>
                <TableBody>
                  {(flop?.peu_vendus ?? []).map((p, i) => (
                    <TableRow key={i}>
                      <TableCell className="font-mono text-xs">{p.code}</TableCell>
                      <TableCell>{p.titre}</TableCell>
                      <TableCell className="text-right">{p.qte}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </div>
      {top && (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Top 10 (histogramme)</CardTitle>
          </CardHeader>
          <CardContent>
            <TopBarChart data={top} />
          </CardContent>
        </Card>
      )}
    </div>
  );
}
