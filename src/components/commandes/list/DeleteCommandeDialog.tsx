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
      description="Cette opération est irréversible. Elle met automatiquement à jour tous les modules liés (stock, comptabilité, livraisons, fidélité, notifications)."
      consequences={[
        "Factures, paiements, écritures comptables et transactions rattachés",
        "Bons de livraison, expéditions, colis, colisage et suivi",
        "Retours, proformas et mouvements de stock générés",
        "Mouvements de fidélité client, notifications et historique d'envois",
        "Recalcul automatique des tournées, statistiques et tableaux de bord",
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
