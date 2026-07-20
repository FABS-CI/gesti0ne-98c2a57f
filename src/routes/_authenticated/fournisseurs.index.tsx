import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Truck, Search, Plus, Download, Pencil, Trash2 } from "lucide-react";
import { Can } from "@/components/rbac/Can";
import { toast } from "sonner";

import {
  listFournisseurs,
  createFournisseur,
  updateFournisseur,
  deleteFournisseur,
  type Fournisseur,
  type FournisseurInput,
} from "@/lib/fournisseurs-api";
import { exportCsv } from "@/lib/export-csv";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { useActifsExerciceIds } from "@/hooks/use-actifs-exercice";
import { describeSupabaseError } from "@/lib/rbac-api";

import { Badge } from "@/components/ui/badge";
import { FilterBadges, type FilterBadge } from "@/components/common/FilterBadges";
import { EmptyState } from "@/components/common/EmptyState";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ResponsiveTable } from "@/components/layout/ResponsiveTable";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ConfirmDeleteDialog } from "@/components/ui/confirm-delete-dialog";

import { authRouteHead } from "@/lib/route-head";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
export const Route = createFileRoute("/_authenticated/fournisseurs/")({
  head: () => authRouteHead("Fournisseurs"),
  component: FournisseursPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

const emptyForm: FournisseurInput = {
  raison_sociale: "",
  contact: "",
  email: "",
  telephone: "",
  adresse: "",
  ville: "",
  actif: true,
};

function FournisseursPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const q = useDebouncedValue(search, 300);
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Fournisseur | null>(null);
  const [form, setForm] = useState<FournisseurInput>(emptyForm);
  const [actifsExercice, setActifsExercice] = useState(false);

  const { data: fournisseursRaw = [], isLoading } = useQuery({
    queryKey: ["fournisseurs", q],
    queryFn: () => listFournisseurs(q),
  });
  const { ids: actifsIds } = useActifsExerciceIds("fournisseur", actifsExercice);
  const fournisseurs =
    actifsExercice && actifsIds
      ? fournisseursRaw.filter((f) => actifsIds.has(f.fournisseur_id))
      : fournisseursRaw;

  const saveMutation = useMutation({
    mutationFn: (input: FournisseurInput) =>
      editing ? updateFournisseur(editing.fournisseur_id, input) : createFournisseur(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["fournisseurs"] });
      toast.success(editing ? "Fournisseur modifié" : "Fournisseur ajouté");
      setOpen(false);
    },
    onError: (e: unknown) => {
      const d = describeSupabaseError(e);
      toast.error(d.title, { description: d.message });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: ({ id, motif }: { id: string; motif: string | null }) =>
      deleteFournisseur(id, motif),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["fournisseurs"] });
      toast.success("Fournisseur supprimé");
      setToDelete(null);
    },
    onError: (e: unknown) => {
      const d = describeSupabaseError(e);
      toast.error(d.title, { description: d.message });
    },
  });

  const [toDelete, setToDelete] = useState<Fournisseur | null>(null);

  const hasActiveFilters = !!q || actifsExercice;
  const resetAllFilters = () => {
    setSearch("");
    setActifsExercice(false);
  };

  function openNew() {
    setEditing(null);
    setForm(emptyForm);
    setOpen(true);
  }

  function openEdit(f: Fournisseur) {
    setEditing(f);
    setForm({
      raison_sociale: f.raison_sociale,
      contact: f.contact ?? "",
      email: f.email ?? "",
      telephone: f.telephone ?? "",
      adresse: f.adresse ?? "",
      ville: f.ville ?? "",
      actif: f.actif,
    });
    setOpen(true);
  }

  function submit() {
    if (!form.raison_sociale.trim()) {
      toast.error("La raison sociale est requise");
      return;
    }
    saveMutation.mutate(form);
  }

  function handleExport() {
    exportCsv(
      "fournisseurs.csv",
      ["Raison sociale", "Contact", "Email", "Téléphone", "Ville", "Statut"],
      fournisseurs.map((f) => [
        f.raison_sociale,
        f.contact ?? "",
        f.email ?? "",
        f.telephone ?? "",
        f.ville ?? "",
        f.actif ? "Actif" : "Inactif",
      ]),
      {
        pageTitle: "LISTE DES FOURNISSEURS",
        summary: [
          { label: "Nombre total de fournisseurs", value: String(fournisseurs.length) },
          {
            label: "Fournisseurs actifs",
            value: String(fournisseurs.filter((f) => f.actif).length),
          },
          {
            label: "Fournisseurs inactifs",
            value: String(fournisseurs.filter((f) => !f.actif).length),
          },
          {
            label: "Villes représentées",
            value: String(new Set(fournisseurs.map((f) => f.ville).filter(Boolean)).size),
          },
        ],
      },
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold">
            <Truck className="h-6 w-6 text-primary" /> Fournisseurs
          </h1>
          <p className="text-sm text-muted-foreground">Gestion des fournisseurs</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={handleExport} disabled={!fournisseurs.length}>
            <Download className="mr-2 h-4 w-4" /> Exporter
          </Button>
          <Button onClick={openNew}>
            <Plus className="mr-2 h-4 w-4" /> Nouveau fournisseur
          </Button>
        </div>
      </div>

      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          placeholder="Rechercher..."
          className="pl-9"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="flex items-center gap-2">
        <Switch
          id="actifs-exercice-fs"
          checked={actifsExercice}
          onCheckedChange={setActifsExercice}
        />
        <Label htmlFor="actifs-exercice-fs" className="text-sm">
          Actifs dans l'exercice
        </Label>
      </div>

      <FilterBadges
        badges={
          [
            q && { key: "q", label: `Recherche : ${q}`, onClear: () => setSearch("") },
            actifsExercice && {
              key: "actif-exo",
              label: "Actifs dans l'exercice",
              onClear: () => setActifsExercice(false),
            },
          ].filter(Boolean) as FilterBadge[]
        }
        onResetAll={resetAllFilters}
      />

      <div className="rounded-lg border">
        <ResponsiveTable stickyFirstCol>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Raison sociale</TableHead>
                <TableHead>Contact</TableHead>
                <TableHead>Email</TableHead>
                <TableHead>Téléphone</TableHead>
                <TableHead>Ville</TableHead>
                <TableHead>Statut</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow>
                  <TableCell colSpan={7} className="py-8 text-center text-muted-foreground">
                    Chargement...
                  </TableCell>
                </TableRow>
              ) : fournisseurs.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} className="py-10 text-center">
                    <EmptyState
                      variant={hasActiveFilters ? "compact" : "rich"}
                      icon={Truck}
                      title={
                        hasActiveFilters
                          ? "Aucun fournisseur ne correspond aux filtres appliqués."
                          : "Aucun fournisseur enregistré."
                      }
                      description={
                        hasActiveFilters
                          ? undefined
                          : "Créez vos fournisseurs pour tracer les approvisionnements, les factures d'achat et les paiements sortants."
                      }
                      onReset={hasActiveFilters ? resetAllFilters : undefined}
                      action={
                        !hasActiveFilters ? (
                          <Button size="sm" onClick={openNew}>
                            <Plus className="mr-2 h-4 w-4" /> Nouveau fournisseur
                          </Button>
                        ) : undefined
                      }
                      className="border-0"
                    />
                  </TableCell>
                </TableRow>
              ) : (
                fournisseurs.map((f) => (
                  <TableRow key={f.fournisseur_id}>
                    <TableCell className="font-medium">{f.raison_sociale}</TableCell>
                    <TableCell>{f.contact ?? "—"}</TableCell>
                    <TableCell>{f.email ?? "—"}</TableCell>
                    <TableCell>{f.telephone ?? "—"}</TableCell>
                    <TableCell>{f.ville ?? "—"}</TableCell>
                    <TableCell>
                      <Badge variant={f.actif ? "default" : "secondary"}>
                        {f.actif ? "Actif" : "Inactif"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="icon" onClick={() => openEdit(f)}>
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Can permission="fournisseurs.supprimer">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => setToDelete(f)}
                        >
                          <Trash2 className="h-4 w-4 text-red-500" />
                        </Button>
                      </Can>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </ResponsiveTable>
      </div>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{editing ? "Modifier le fournisseur" : "Nouveau fournisseur"}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5 sm:col-span-2">
              <Label>Raison sociale</Label>
              <Input
                value={form.raison_sociale}
                onChange={(e) => setForm((f) => ({ ...f, raison_sociale: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Contact</Label>
              <Input
                value={form.contact ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, contact: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Email</Label>
              <Input
                type="email"
                value={form.email ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Téléphone</Label>
              <Input
                value={form.telephone ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, telephone: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Ville</Label>
              <Input
                value={form.ville ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, ville: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5 sm:col-span-2">
              <Label>Adresse</Label>
              <Input
                value={form.adresse ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, adresse: e.target.value }))}
              />
            </div>
            <div className="flex items-center gap-2 sm:col-span-2">
              <Switch
                checked={form.actif}
                onCheckedChange={(v) => setForm((f) => ({ ...f, actif: v }))}
              />
              <Label>Actif</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Annuler
            </Button>
            <Button onClick={submit} disabled={saveMutation.isPending}>
              {editing ? "Enregistrer" : "Créer"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDeleteDialog
        open={!!toDelete}
        onOpenChange={(o) => !o && setToDelete(null)}
        title="Supprimer ce fournisseur ?"
        entityLabel="le fournisseur"
        entityName={toDelete?.raison_sociale}
        description="La suppression est bloquée si le fournisseur possède des approvisionnements ou un solde d'ouverture. Désactivez la fiche dans ce cas."
        motifRequired
        pending={deleteMutation.isPending}
        onConfirm={(motif) => {
          if (!toDelete) return;
          deleteMutation.mutate({ id: toDelete.fournisseur_id, motif });
        }}
      />
    </div>
  );
}
