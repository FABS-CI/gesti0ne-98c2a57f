import { createFileRoute, Link } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { ArrowLeft, Ban, Calendar, CreditCard, FileText, Trash2, User } from "lucide-react";
import { toast } from "sonner";

import {
  annulerPaiement,
  getPaiement,
  MODE_PAIEMENT_LABEL,
  STATUT_PAIEMENT_LABEL,
  supprimerPaiementDefinitif,
} from "@/lib/paiements-api";
import { formatFCFA } from "@/lib/format";
import { invalidatePaiement } from "@/lib/cache-invalidation";
import { useUserRoles } from "@/hooks/use-user-roles";
import { useNavigate } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";

export const Route = createFileRoute("/_authenticated/paiements/$paiementId")({
  component: PaiementDetailPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function frDate(d: string | null | undefined) {
  return d ? new Date(d).toLocaleDateString("fr-FR") : "—";
}

function PaiementDetailPage() {
  const { paiementId } = Route.useParams();
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const { isSuperAdmin, hasRole } = useUserRoles();
  const canHardDelete = isSuperAdmin || hasRole("directeur_general");
  const [raison, setRaison] = useState("");
  const [notes, setNotes] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteMotif, setDeleteMotif] = useState("");
  const { data: paiement, isLoading } = useQuery({
    queryKey: ["paiement", paiementId],
    queryFn: () => getPaiement(paiementId),
  });

  const cancelMutation = useMutation({
    mutationFn: () => annulerPaiement(paiementId, raison, notes),
    onSuccess: () => {
      toast.success("Paiement annulé — KPI client mis à jour");
      setDialogOpen(false);
      setRaison("");
      setNotes("");
      invalidatePaiement(queryClient, {
        paiementId,
        factureId: (paiement as { facture_id?: string } | undefined)?.facture_id,
        clientId: (paiement as { client_id?: string } | undefined)?.client_id,
      });
    },
    onError: (e: unknown) => toast.error(e instanceof Error ? e.message : "Erreur"),
  });

  const deleteMutation = useMutation({
    mutationFn: () => supprimerPaiementDefinitif(paiementId, deleteMotif),
    onSuccess: () => {
      toast.success("Paiement supprimé définitivement");
      setDeleteOpen(false);
      setDeleteMotif("");
      invalidatePaiement(queryClient, {
        paiementId,
        factureId: (paiement as { facture_id?: string } | undefined)?.facture_id,
        clientId: (paiement as { client_id?: string } | undefined)?.client_id,
      });
      navigate({ to: "/paiements" });
    },
    onError: (e: unknown) => toast.error(e instanceof Error ? e.message : "Erreur"),
  });

  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (!paiement)
    return (
      <div className="space-y-4">
        <p className="text-muted-foreground">Paiement introuvable.</p>
        <Button asChild variant="outline">
          <Link to="/paiements">Retour</Link>
        </Button>
      </div>
    );

  const statut = STATUT_PAIEMENT_LABEL[paiement.statut];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button asChild variant="ghost" size="icon">
            <Link to="/paiements">
              <ArrowLeft className="h-5 w-5" />
            </Link>
          </Button>
          <div>
            <h1 className="text-xl font-bold">Paiement {paiement.reference}</h1>
            <p className="text-sm text-muted-foreground">
              {paiement.client_nom ?? "Client non renseigné"}
            </p>
          </div>
        </div>
        {statut && (
          <Badge style={{ backgroundColor: statut.color }} className="text-white">
            {statut.label}
          </Badge>
        )}
        {paiement.statut !== "annule" && (
          <AlertDialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <AlertDialogTrigger asChild>
              <Button variant="destructive" size="sm">
                <Ban className="mr-2 h-4 w-4" /> Annuler ce paiement
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Annuler ce paiement ?</AlertDialogTitle>
                <AlertDialogDescription>
                  Le montant de {formatFCFA(paiement.montant)} sera retiré de la facture liée. Le
                  statut de la facture, l'encours et le solde du client seront recalculés
                  automatiquement. Cette action est irréversible.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <div className="space-y-3 py-2">
                <div className="space-y-1">
                  <Label htmlFor="raison">
                    Raison <span className="text-destructive">*</span>
                  </Label>
                  <Textarea
                    id="raison"
                    value={raison}
                    onChange={(e) => setRaison(e.target.value)}
                    placeholder="Motif de l'annulation (obligatoire)"
                    rows={2}
                  />
                </div>
                <div className="space-y-1">
                  <Label htmlFor="notes-annul">Notes (optionnel)</Label>
                  <Textarea
                    id="notes-annul"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="Informations complémentaires"
                    rows={2}
                  />
                </div>
              </div>
              <AlertDialogFooter>
                <AlertDialogCancel>Retour</AlertDialogCancel>
                <AlertDialogAction
                  onClick={(e) => {
                    e.preventDefault();
                    if (!raison.trim()) {
                      toast.error("Raison obligatoire");
                      return;
                    }
                    cancelMutation.mutate();
                  }}
                  disabled={cancelMutation.isPending || !raison.trim()}
                >
                  Confirmer l'annulation
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        )}
        {canHardDelete && (
          <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
            <AlertDialogTrigger asChild>
              <Button variant="destructive" size="sm">
                <Trash2 className="mr-2 h-4 w-4" /> Supprimer définitivement
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Supprimer définitivement ce paiement ?</AlertDialogTitle>
                <AlertDialogDescription>
                  Action irréversible réservée aux super-admins. Le paiement de{" "}
                  {formatFCFA(paiement.montant)} sera effacé de la base. Préférez « Annuler ce
                  paiement » pour conserver la traçabilité.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <div className="space-y-1 py-2">
                <Label htmlFor="motif-del">
                  Motif <span className="text-destructive">*</span>
                </Label>
                <Textarea
                  id="motif-del"
                  value={deleteMotif}
                  onChange={(e) => setDeleteMotif(e.target.value)}
                  placeholder="Justification (doublon, saisie test, etc.)"
                  rows={2}
                />
              </div>
              <AlertDialogFooter>
                <AlertDialogCancel>Retour</AlertDialogCancel>
                <AlertDialogAction
                  onClick={(e) => {
                    e.preventDefault();
                    if (!deleteMotif.trim()) {
                      toast.error("Motif obligatoire");
                      return;
                    }
                    deleteMutation.mutate();
                  }}
                  disabled={deleteMutation.isPending || !deleteMotif.trim()}
                >
                  Supprimer définitivement
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        )}
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <User className="h-4 w-4" /> Client
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{paiement.client_nom ?? "—"}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <Calendar className="h-4 w-4" /> Date
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">{frDate(paiement.date_paiement)}</CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <CreditCard className="h-4 w-4" /> Mode
            </CardTitle>
          </CardHeader>
          <CardContent className="font-medium">
            {MODE_PAIEMENT_LABEL[paiement.mode_paiement] ?? paiement.mode_paiement}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm text-muted-foreground">
              <FileText className="h-4 w-4" /> Montant
            </CardTitle>
          </CardHeader>
          <CardContent className="text-lg font-bold text-primary">
            {formatFCFA(paiement.montant)}
          </CardContent>
        </Card>
      </div>

      {paiement.facture_id && (
        <Card>
          <CardHeader>
            <CardTitle>Facture liée</CardTitle>
          </CardHeader>
          <CardContent>
            <Button asChild variant="outline" size="sm">
              <Link to="/factures/$factureId" params={{ factureId: paiement.facture_id }}>
                Voir la facture
              </Link>
            </Button>
          </CardContent>
        </Card>
      )}

      {paiement.notes && (
        <Card>
          <CardHeader>
            <CardTitle>Notes</CardTitle>
          </CardHeader>
          <CardContent className="whitespace-pre-wrap text-sm text-muted-foreground">
            {paiement.notes}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
