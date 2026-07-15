import { useState } from "react";
import { Button } from "@/components/ui/button";
import { ResponsiveDialog } from "@/components/ui/responsive-dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

type Props = {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  reference?: string;
  pending?: boolean;
  onConfirm: (motif: string) => void;
};

export function RejeterPaiementDialog({ open, onOpenChange, reference, pending, onConfirm }: Props) {
  const [motif, setMotif] = useState("");
  const disabled = motif.trim().length < 3 || pending;
  return (
    <ResponsiveDialog
      open={open}
      onOpenChange={(v) => {
        if (!v) setMotif("");
        onOpenChange(v);
      }}
      title={`Rejeter le paiement ${reference ?? ""}`}
      description="Le paiement sera passé au statut « Rejeté ». Aucun impact comptable ni sur la fidélité client. L'action est tracée dans le journal d'audit."
      footer={
        <>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Annuler
          </Button>
          <Button variant="destructive" disabled={disabled} onClick={() => onConfirm(motif.trim())}>
            {pending ? "Rejet en cours…" : "Confirmer le rejet"}
          </Button>
        </>
      }
    >
      <div className="space-y-2">
        <Label htmlFor="motif-rejet">
          Motif du rejet <span className="text-destructive">*</span>
        </Label>
        <Textarea
          id="motif-rejet"
          value={motif}
          onChange={(e) => setMotif(e.target.value)}
          placeholder="Ex. montant erroné, mode de paiement invalide, doublon…"
          rows={4}
        />
        <p className="text-xs text-muted-foreground">Minimum 3 caractères.</p>
      </div>
    </ResponsiveDialog>
  );
}
