import { Link } from "@tanstack/react-router";
import { Plus, ShoppingCart } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ResponsiveTable } from "@/components/layout/ResponsiveTable";
import { CommandeRow } from "@/components/commandes/CommandeRow";
import { CommandeCard } from "@/components/commandes/CommandeCard";
import type { Commande } from "@/lib/commandes-api";

export function CommandesTable({
  items,
  isLoading,
  q,
  statut,
  onResetFilters,
  readOnly,
  isSuperAdmin,
  canModifier,
  canValider,
  onValider,
  validerPending,
  onDelete,
}: {
  items: Commande[];
  isLoading: boolean;
  q: string;
  statut: string;
  onResetFilters: () => void;
  readOnly: boolean;
  isSuperAdmin: boolean;
  canModifier: boolean;
  canValider: boolean;
  onValider: (id: string) => void;
  validerPending: boolean;
  onDelete: (c: Commande) => void;
}) {
  const emptyState =
    q || statut !== "all" ? (
      <div className="flex flex-col items-center gap-2 text-muted-foreground">
        <ShoppingCart className="h-8 w-8 opacity-40" />
        <p className="font-medium">Aucune commande ne correspond aux filtres</p>
        <Button variant="outline" size="sm" onClick={onResetFilters}>
          Réinitialiser les filtres
        </Button>
      </div>
    ) : (
      <div className="flex flex-col items-center gap-2 text-muted-foreground">
        <ShoppingCart className="h-8 w-8 opacity-40" />
        <p className="font-medium">Aucune commande pour le moment</p>
        {!readOnly && (
          <Button asChild size="sm">
            <Link to="/commandes/nouvelle">
              <Plus className="mr-2 h-4 w-4" /> Créer la première commande
            </Link>
          </Button>
        )}
      </div>
    );

  const mobileCards = (
    <div className="space-y-2 p-2">
      {isLoading ? (
        <div className="py-10 text-center text-muted-foreground">Chargement…</div>
      ) : items.length === 0 ? (
        <div className="py-8">{emptyState}</div>
      ) : (
        items.map((c) => (
          <CommandeCard
            key={c.commande_id}
            commande={c}
            readOnly={readOnly}
            isSuperAdmin={isSuperAdmin}
            canModifier={canModifier}
            canValider={canValider}
            onValider={onValider}
            validerPending={validerPending}
            onDelete={onDelete}
          />
        ))
      )}
    </div>
  );

  return (
    <div className="overflow-hidden rounded-xl border bg-card shadow-sm">
      <ResponsiveTable mobileCards={mobileCards}>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Référence</TableHead>
              <TableHead>Client</TableHead>
              <TableHead>Date</TableHead>
              <TableHead>Statut</TableHead>
              <TableHead className="text-right">Total</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableRow>
                <TableCell colSpan={6} className="py-10 text-center text-muted-foreground">
                  Chargement…
                </TableCell>
              </TableRow>
            ) : items.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="py-12 text-center">
                  {emptyState}
                </TableCell>
              </TableRow>
            ) : (
              items.map((c) => (
                <CommandeRow
                  key={c.commande_id}
                  commande={c}
                  readOnly={readOnly}
                  isSuperAdmin={isSuperAdmin}
                  canModifier={canModifier}
                  canValider={canValider}
                  onValider={onValider}
                  validerPending={validerPending}
                  onDelete={onDelete}
                />
              ))
            )}
          </TableBody>
        </Table>
      </ResponsiveTable>
    </div>
  );
}
