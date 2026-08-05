import { Link, useNavigate } from "@tanstack/react-router";
import { Eye, Pencil, PowerOff, Package, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { EmptyState } from "@/components/common/EmptyState";
import { formatFCFA } from "@/lib/format";
import { CATEGORIE_LABEL } from "@/lib/company";
import type { Produit } from "@/lib/produits-api";
import { Can } from "@/components/rbac/Can";
import { ProductCoverThumb } from "@/components/produits/ProductCoverThumb";

interface Props {
  items: Produit[];
  isLoading: boolean;
  canSeeSensitive: boolean;
  canMutate: boolean;
  onEdit: (p: Produit) => void;
  onDisable: (p: Produit) => void;
  hasActiveFilters?: boolean;
  onResetFilters?: () => void;
  onCreate?: () => void;
}

export function ProduitsTable({
  items,
  isLoading,
  canSeeSensitive,
  canMutate,
  onEdit,
  onDisable,
  hasActiveFilters = false,
  onResetFilters,
  onCreate,
}: Props) {
  const navigate = useNavigate();
  const colSpan = canSeeSensitive ? 11 : 6;
  return (
    <div className="rounded-lg border bg-card">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-14"></TableHead>
            <TableHead>Réf.</TableHead>
            <TableHead>Titre</TableHead>
            <TableHead>Catégorie</TableHead>
            <TableHead>Niveau</TableHead>
            <TableHead>Matière</TableHead>
            {canSeeSensitive && <TableHead className="text-right">Prix vente</TableHead>}
            {canSeeSensitive && <TableHead className="text-right">Valeur vente</TableHead>}
            {canSeeSensitive && <TableHead className="text-right">Stock</TableHead>}
            {canSeeSensitive && <TableHead>Statut</TableHead>}
            {canMutate && <TableHead className="text-right">Actions</TableHead>}
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading ? (
            <TableRow>
              <TableCell colSpan={colSpan} className="py-10 text-center text-muted-foreground">
                Chargement…
              </TableCell>
            </TableRow>
          ) : items.length === 0 ? (
            <TableRow>
              <TableCell colSpan={colSpan} className="py-6">
                <EmptyState
                  variant={hasActiveFilters ? "compact" : "rich"}
                  icon={Package}
                  title={
                    hasActiveFilters
                      ? "Aucun produit ne correspond aux filtres appliqués."
                      : "Aucun produit enregistré."
                  }
                  description={
                    hasActiveFilters
                      ? undefined
                      : "Créez votre catalogue pour commencer à vendre, gérer le stock et suivre les marges."
                  }
                  onReset={hasActiveFilters ? onResetFilters : undefined}
                  action={
                    !hasActiveFilters && canMutate && onCreate ? (
                      <Button size="sm" onClick={onCreate}>
                        <Plus className="mr-2 h-4 w-4" /> Nouveau produit
                      </Button>
                    ) : undefined
                  }
                  className="border-none"
                />
              </TableCell>
            </TableRow>
          ) : (
            items.map((p) => {
              const low = p.stock <= p.seuil_alerte;
              return (
                <TableRow
                  key={p.produit_id}
                  className={`group transition-colors odd:bg-muted/20 ${canMutate ? "cursor-pointer hover:bg-primary/5" : ""} ${low ? "border-l-2 border-l-red-500/60" : ""}`}
                  onClick={
                    canMutate
                      ? () =>
                          navigate({
                            to: "/produits/$produitId",
                            params: { produitId: p.produit_id },
                          })
                      : undefined
                  }
                >
                  <TableCell className="py-1.5">
                    <ProductCoverThumb produit={p} size="sm" className="shadow-sm" />
                  </TableCell>
                  <TableCell className="font-mono text-xs select-all" title="Cliquer pour sélectionner la référence">{p.reference}</TableCell>
                  <TableCell className="font-medium">
                    {canMutate ? (
                      <Link
                        to="/produits/$produitId"
                        params={{ produitId: p.produit_id }}
                        className="hover:underline"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {p.titre}
                      </Link>
                    ) : (
                      <span>{p.titre}</span>
                    )}
                    {p.auteur && (
                      <span className="block text-xs text-muted-foreground">{p.auteur}</span>
                    )}
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary">{CATEGORIE_LABEL[p.categorie] ?? p.categorie}</Badge>
                  </TableCell>
                  <TableCell>{p.niveau || "—"}</TableCell>
                  <TableCell>{p.matiere || "—"}</TableCell>
                  {canSeeSensitive && (
                    <TableCell className="text-right">{formatFCFA(p.prix_vente)}</TableCell>
                  )}
                  {canSeeSensitive && (
                    <TableCell className="text-right font-medium text-emerald-600">
                      {formatFCFA(p.stock * p.prix_vente)}
                    </TableCell>
                  )}
                  {canSeeSensitive && (
                    <TableCell className="text-right">
                      <span className={low ? "font-semibold text-destructive" : ""}>{p.stock}</span>
                    </TableCell>
                  )}
                  {canSeeSensitive && (
                    <TableCell>
                      {p.actif ? (
                        <span className="inline-flex items-center gap-1 text-xs text-emerald-600">
                          <span className="h-2 w-2 rounded-full bg-emerald-500" /> Actif
                        </span>
                      ) : (
                        <Badge variant="secondary">Désactivé</Badge>
                      )}
                    </TableCell>
                  )}
                  {canMutate && (
                    <TableCell className="text-right" onClick={(e) => e.stopPropagation()}>
                      <div className="flex justify-end gap-1 opacity-60 transition-opacity group-hover:opacity-100">
                        <Button variant="ghost" size="icon" asChild title="Voir">
                          <Link to="/produits/$produitId" params={{ produitId: p.produit_id }}>
                            <Eye className="h-4 w-4" />
                          </Link>
                        </Button>
                        <Button variant="ghost" size="icon" onClick={() => onEdit(p)} title="Modifier">
                          <Pencil className="h-4 w-4" />
                        </Button>
                        {p.actif && (
                          <Can permission="produits.supprimer">
                            <Button
                              variant="ghost"
                              size="icon"
                              onClick={() => onDisable(p)}
                              title="Désactiver"
                              className="hover:bg-destructive/10"
                            >
                              <PowerOff className="h-4 w-4 text-destructive" />
                            </Button>
                          </Can>
                        )}
                      </div>
                    </TableCell>
                  )}
                </TableRow>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
