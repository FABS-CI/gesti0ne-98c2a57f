import { AlertTriangle, Building2, CheckCircle2, Loader2, Users } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { formatFCFA, formatDate } from "@/lib/format";
import type { PreviewResult } from "./exercices-shared";

type Props = {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  preview: PreviewResult | undefined;
  loading: boolean;
  activerSuivant: boolean;
  setActiverSuivant: (v: boolean) => void;
  onValidate: () => void;
  submitting: boolean;
};

export function CloturePreviewDialog({
  open,
  onOpenChange,
  preview,
  loading,
  activerSuivant,
  setActiverSuivant,
  onValidate,
  submitting,
}: Props) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Aperçu de clôture</DialogTitle>
          <DialogDescription>
            Vérifiez les données à reporter avant de valider la clôture définitive.
          </DialogDescription>
        </DialogHeader>

        {loading || !preview ? (
          <div className="flex items-center gap-2 py-8 text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            Calcul en cours…
          </div>
        ) : (
          <div className="space-y-4">
            <div className="rounded-lg border p-3">
              <p className="text-xs text-muted-foreground">Exercice à clôturer</p>
              <p className="font-semibold">
                {preview.exercice.code} ({formatDate(preview.exercice.date_debut)} → {formatDate(preview.exercice.date_fin)}
                )
              </p>
              {preview.exercice_suivant && (
                <p className="mt-1 text-sm text-muted-foreground">
                  Suivant : <strong>{preview.exercice_suivant.code}</strong>
                </p>
              )}
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              <div className="rounded-lg border p-3">
                <p className="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase text-muted-foreground">
                  <Users className="h-3.5 w-3.5" /> Clients
                </p>
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span>Débiteurs</span>
                    <span className="font-medium">
                      {preview.clients.debiteurs_count} — {formatFCFA(preview.clients.total_debit)}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Créditeurs (avances)</span>
                    <span className="font-medium">
                      {preview.clients.crediteurs_count} —{" "}
                      {formatFCFA(preview.clients.total_credit)}
                    </span>
                  </div>
                </div>
              </div>
              <div className="rounded-lg border p-3">
                <p className="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase text-muted-foreground">
                  <Building2 className="h-3.5 w-3.5" /> Fournisseurs
                </p>
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span>Débiteurs</span>
                    <span className="font-medium">
                      {preview.fournisseurs.debiteurs_count} —{" "}
                      {formatFCFA(preview.fournisseurs.total_debit)}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>Créditeurs</span>
                    <span className="font-medium">
                      {preview.fournisseurs.crediteurs_count} —{" "}
                      {formatFCFA(preview.fournisseurs.total_credit)}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {preview.blocages.length > 0 && (
              <div className="space-y-2">
                {preview.blocages.map((b) => (
                  <Alert key={b.code} variant={b.severite === "error" ? "destructive" : "default"}>
                    <AlertTriangle className="h-4 w-4" />
                    <AlertTitle className="text-xs uppercase">{b.severite}</AlertTitle>
                    <AlertDescription>{b.message}</AlertDescription>
                  </Alert>
                ))}
              </div>
            )}

            <label className="flex items-start gap-2 rounded-lg border p-3 text-sm">
              <Checkbox
                checked={activerSuivant}
                onCheckedChange={(v) => setActiverSuivant(v === true)}
              />
              <span>
                Activer immédiatement l'exercice suivant (
                <strong>{preview.exercice_suivant?.code ?? "—"}</strong>) après la clôture.
              </span>
            </label>
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Annuler
          </Button>
          <Button disabled={!preview?.peut_cloturer || submitting} onClick={onValidate}>
            <CheckCircle2 className="mr-1 h-4 w-4" />
            Valider la clôture
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
