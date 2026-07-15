import { Link } from "@tanstack/react-router";
import { ArrowRight, BookOpenCheck, Boxes, FileText } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatFCFACompact } from "@/lib/format";
import type { DashboardOverview } from "@/hooks/use-dashboard-overview";

export function DashboardModulesNav({ data }: { data: DashboardOverview | undefined }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <Link to="/stock" className="group">
        <Card className="h-full transition-colors group-hover:border-primary">
          <CardHeader className="flex flex-row items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-amber-500/10 text-amber-600">
                <Boxes className="h-5 w-5" />
              </span>
              <CardTitle className="text-base">Stocks</CardTitle>
            </div>
            <ArrowRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-1" />
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              {data?.nbStockBas ?? 0} article(s) sous le seuil d'alerte.
            </p>
          </CardContent>
        </Card>
      </Link>

      <Link to="/comptabilite" className="group">
        <Card className="h-full transition-colors group-hover:border-primary">
          <CardHeader className="flex flex-row items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-sky-500/10 text-sky-600">
                <BookOpenCheck className="h-5 w-5" />
              </span>
              <CardTitle className="text-base">Comptabilité</CardTitle>
            </div>
            <ArrowRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-1" />
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              Journal comptable, écritures et lettrage.
            </p>
          </CardContent>
        </Card>
      </Link>

      <Link to="/factures" className="group">
        <Card className="h-full transition-colors group-hover:border-primary">
          <CardHeader className="flex flex-row items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-red-500/10 text-red-600">
                <FileText className="h-5 w-5" />
              </span>
              <CardTitle className="text-base">Factures</CardTitle>
            </div>
            <ArrowRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-1" />
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              {data?.nbRetards ?? 0} facture(s) en retard ·{" "}
              {formatFCFACompact(data?.montantRetard ?? 0)}
            </p>
          </CardContent>
        </Card>
      </Link>
    </div>
  );
}
