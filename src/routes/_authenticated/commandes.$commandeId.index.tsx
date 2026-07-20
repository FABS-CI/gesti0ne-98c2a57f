import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, Calendar, FileText, Pencil, Receipt, User } from "lucide-react";

import { getCommande, getCommandeLignes, STATUT_LABEL } from "@/lib/commandes-api";
import { formatFCFA } from "@/lib/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { usePermissions } from "@/hooks/use-permissions";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export const Route = createFileRoute("/_authenticated/commandes/$commandeId/")({
  component: CommandeDetailPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function frDate(d: string | null | undefined) {
  return d ? new Date(d).toLocaleDateString("fr-FR") : "—";
}

function CommandeDetailPage() {
  const { commandeId } = Route.useParams();
  const { has: hasPermission, isSuperAdmin } = usePermissions();
  const canModifier = hasPermission("commandes.modifier");
  const { data: commande, isLoading } = useQuery({
    queryKey: ["commande", commandeId],
    queryFn: () => getCommande(commandeId),
  });
  const { data: lignes = [] } = useQuery({
    queryKey: ["commande-lignes", commandeId],
    queryFn: () => getCommandeLignes(commandeId),
  });

  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (!commande)
    return (
      <div className="space-y-4">
        <p className="text-muted-foreground">Commande introuvable.</p>
        <Button asChild variant="outline">
          <Link to="/commandes">Retour</Link>
        </Button>
      </div>
    );

  const statut = STATUT_LABEL[commande.statut];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button asChild variant="ghost" size="icon">
            <Link to="/commandes">
              <ArrowLeft className="h-5 w-5" />
            </Link>
          </Button>
          <div>
            <h1 className="text-xl font-bold">Commande {commande.reference}</h1>
            <p className="text-sm text-muted-foreground">
              {commande.client_nom ?? "Client non renseigné"}
            </p>
          </div>
        </div>
        {statut && (
          <Badge style={{ backgroundColor: statut.color }} className="text-white">
            {statut.label}
          </Badge>
        )}
        {canModifier &&
          (isSuperAdmin ||
            commande.statut === "brouillon" ||
            commande.statut === "en_attente_validation") && (
            <Button asChild variant="default" size="sm">
              <Link to="/commandes/$commandeId/modifier" params={{ commandeId }}>
                <Pencil className="mr-2 h-4 w-4" />
                Modifier la commande
              </Link>
            </Button>
          )}
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <User className="h-4 w-4" /> Client
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{commande.client_nom ?? "—"}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <Calendar className="h-4 w-4" /> Date
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{frDate(commande.date_commande)}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <FileText className="h-4 w-4" /> Remise
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">
            {(() => {
              const brut = Number(commande.total_ht_brut ?? 0);
              const remLignes = Number(commande.total_remises_lignes ?? 0);
              const remGlobM = Number(commande.remise_globale_montant ?? 0);
              const remGlobPct = Number(commande.remise_globale_pct ?? 0);
              const totalRem = remLignes + remGlobM;
              const effectivePct = brut > 0 ? Math.round((totalRem / brut) * 1000) / 10 : 0;
              return (
                <>
                  {effectivePct} %
                  {totalRem > 0 && (
                    <span className="ml-2 text-sm text-muted-foreground">
                      ({formatFCFA(totalRem)})
                    </span>
                  )}
                  {remLignes > 0 && (
                    <div className="text-xs text-muted-foreground mt-1">
                      Remises lignes : {formatFCFA(remLignes)}
                    </div>
                  )}
                  {remGlobM > 0 && (
                    <div className="text-xs text-muted-foreground">
                      Remise globale : {remGlobPct}% ({formatFCFA(remGlobM)})
                    </div>
                  )}
                </>
              );
            })()}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <Receipt className="h-4 w-4" /> Total
            </CardTitle>
          </CardHeader>
          <CardContent className="text-lg font-bold text-primary">
            {formatFCFA(commande.montant_total)}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Lignes de commande</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Désignation</TableHead>
                <TableHead className="text-right">Qté</TableHead>
                <TableHead className="text-right">P.U.</TableHead>
                <TableHead className="text-right">Total</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {lignes.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-muted-foreground">
                    Aucune ligne
                  </TableCell>
                </TableRow>
              ) : (
                lignes.map((l) => (
                  <TableRow key={l.ligne_id}>
                    <TableCell>{l.designation}</TableCell>
                    <TableCell className="text-right">{l.quantite}</TableCell>
                    <TableCell className="text-right">{formatFCFA(l.prix_unitaire)}</TableCell>
                    <TableCell className="text-right font-medium">
                      {formatFCFA(l.total_ligne)}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {commande.notes && (
        <Card>
          <CardHeader>
            <CardTitle>Notes</CardTitle>
          </CardHeader>
          <CardContent className="whitespace-pre-wrap text-sm text-muted-foreground">
            {commande.notes}
          </CardContent>
        </Card>
      )}
    </div>
  );
}