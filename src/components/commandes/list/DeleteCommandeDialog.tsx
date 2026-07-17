import { ConfirmDeleteDialog } from "@/components/ui/confirm-delete-dialog";
import type { Commande } from "@/lib/commandes-api";

export function DeleteCommandeDialog({
  commande,
  onOpenChange,
  onConfirm,
  pending,
}: {
  commande: Commande | null;
  onOpenChange: (open: boolean) => void;
  onConfirm: (motif: string | null) => void;
  pending: boolean;
}) {
  const label = commande?.client_nom
    ? `${commande.reference} — ${commande.client_nom}`
    : commande?.reference ?? "";

  return (
    <ConfirmDeleteDialog
      open={!!commande}
      onOpenChange={onOpenChange}
      title="Supprimer définitivement cette commande ?"
      entityLabel="le bon de commande"
      entityName={label}
      description="Cette opération est irréversible. Elle est refusée si un paiement validé existe, si une facture non annulée est rattachée, ou si un BL a été expédié/livré. Dans ce cas, annuler la commande (qui remet le stock et annule les documents comptables) au lieu de la supprimer."
      consequences={[
        "Refus si paiement validé, facture non annulée, ou BL expédié/livré",
        "Suppression : commande, lignes, proformas, factures annulées, BL, paiements annulés",
        "Suppression : bons de livraison, colisages, colis, livraisons, expéditions, suivi",
        "Suppression : retours, mouvements de stock, notifications rattachés",
        "Écritures comptables des factures/paiements supprimées automatiquement via triggers",
        "Recalcul automatique du solde client",
      ]}
      motifRequired
      motifPlaceholder="Motif de la suppression (obligatoire pour audit)"
      requireTyping="SUPPRIMER"
      confirmLabel="Supprimer définitivement"
      pending={pending}
      onConfirm={onConfirm}
    />
  );
}
