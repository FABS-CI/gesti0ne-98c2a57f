import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, User, Package, Calendar, MapPin, Phone, Printer } from "lucide-react";

import { getRetour, STATUT_RETOUR_LABEL } from "@/lib/retours-api";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export const Route = createFileRoute("/_authenticated/retours/$retourId")({
  component: RetourDetailPage,
});

function frDate(d: string | null | undefined) {
  return d ? new Date(d).toLocaleDateString("fr-FR") : "—";
}

function RetourDetailPage() {
  const { retourId } = Route.useParams();
  const { data: retour, isLoading } = useQuery({
    queryKey: ["retour", retourId],
    queryFn: () => getRetour(retourId),
  });

  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (!retour)
    return (
      <div className="space-y-4 p-6">
        <p className="text-muted-foreground">Retour introuvable.</p>
        <Button asChild variant="outline">
          <Link to="/retours">Retour à la liste</Link>
        </Button>
      </div>
    );

  const st = STATUT_RETOUR_LABEL[retour.statut];
  const titre = retour.numero ?? retour.reference;

  return (
    <div className="space-y-6 p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button asChild variant="ghost" size="icon">
            <Link to="/retours">
              <ArrowLeft className="h-5 w-5" />
            </Link>
          </Button>
          <div>
            <h1 className="text-xl font-bold">{titre}</h1>
            <p className="text-sm text-muted-foreground">
              {retour.etablissement ?? retour.client_nom ?? "—"}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {st && (
            <Badge style={{ backgroundColor: st.color }} className="text-white">
              {st.label}
            </Badge>
          )}
          <Button variant="outline" onClick={() => window.print()}>
            <Printer className="h-4 w-4 mr-2" />
            Imprimer
          </Button>
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <User className="h-4 w-4" /> Client
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">
            {retour.etablissement ?? retour.client_nom ?? "—"}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <User className="h-4 w-4" /> Représentant
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{retour.representant_nom ?? "—"}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <Phone className="h-4 w-4" /> Téléphone
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{retour.telephone ?? "—"}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <MapPin className="h-4 w-4" /> Ville
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{retour.ville ?? "—"}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <Calendar className="h-4 w-4" /> Date
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{frDate(retour.date_retour)}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <Package className="h-4 w-4" /> Produits
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">
            {retour.nb_produits} ({retour.total_quantite} unités)
          </CardContent>
        </Card>
        <Card className="sm:col-span-2">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">Enregistré par</CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{retour.created_by_nom ?? "—"}</CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Produits retournés</CardTitle>
        </CardHeader>
        <CardContent>
          {retour.lignes.length === 0 ? (
            <p className="text-sm text-muted-foreground">Aucune ligne.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Désignation</TableHead>
                  <TableHead>Référence</TableHead>
                  <TableHead className="text-right">Quantité</TableHead>
                  <TableHead>Motif</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {retour.lignes.map((l) => (
                  <TableRow key={l.ligne_id}>
                    <TableCell className="font-medium">{l.designation}</TableCell>
                    <TableCell className="font-mono text-xs">
                      {l.reference_produit ?? "—"}
                    </TableCell>
                    <TableCell className="text-right">{l.quantite}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {l.motif ?? "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {retour.observations && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Observations</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground whitespace-pre-wrap">
            {retour.observations}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
