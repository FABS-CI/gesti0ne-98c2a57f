import { createFileRoute, useNavigate, useParams } from "@tanstack/react-router";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, CheckCircle2, Loader2, Navigation, Plus, Save, Trash2 } from "lucide-react";
import { toast } from "sonner";

import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Can } from "@/components/rbac/Can";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
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
import { invalidateColisage } from "@/lib/cache-invalidation";
import { DateColisPicker } from "@/components/tournees/DateColisPicker";
import { usePermissions } from "@/hooks/use-permissions";
import { ConfirmDeleteDialog } from "@/components/ui/confirm-delete-dialog";

export const Route = createFileRoute("/_authenticated/tournees/$tourneeId")({
  component: EditTourneePage,
});

type Tournee = {
  tournee_id: string;
  reference: string;
  date_tournee: string | null;
  responsable_nom: string | null;
  chauffeur_nom: string | null;
  vehicule_id: string | null;
  statut: string;
  notes: string | null;
  cout_carburant: number | null;
  cout_peages: number | null;
  cout_repas: number | null;
  cout_expeditions: number | null;
  cout_manutentions: number | null;
  cout_autres: number | null;
  cout_livraison: number | null;
  type_tournee: string | null;
  cout_total: number | null;
  validation_statut?: string | null;
  validation_at?: string | null;
  validation_commentaire?: string | null;
  mode_reglement?: string | null;
  nb_colis: number | null;
  nb_cartons: number | null;
  nb_clients: number | null;
  cloture_mode: string | null;
  cloture_at: string | null;
  cloture_by: string | null;
};

type ColisRow = {
  colis_id: string;
  reference: string | null;
  nb_cartons: number | null;
  commande_id: string | null;
  destinataire: string | null;
  ville_livraison: string | null;
  quartier: string | null;
  livreur_nom: string | null;
};

type CommandeRow = { commande_id: string; client_id: string | null; client_nom: string | null };
type Vehicule = { vehicule_id: string; immatriculation: string | null };

const STATUTS = [
  { value: "preparee", label: "Préparée" },
  { value: "en_cours", label: "En cours" },
  { value: "terminee", label: "Terminée" },
  { value: "annulee", label: "Annulée" },
];

const COST_FIELDS: Array<{ key: keyof Tournee; label: string }> = [
  { key: "cout_carburant", label: "Carburant" },
  { key: "cout_peages", label: "Péages" },
  { key: "cout_repas", label: "Repas" },
  { key: "cout_livraison", label: "Frais de livraison" },
  { key: "cout_expeditions", label: "Expéditions" },
  { key: "cout_manutentions", label: "Manutentions" },
  { key: "cout_autres", label: "Autres" },
];

function EditTourneePage() {
  const { tourneeId } = useParams({ from: "/_authenticated/tournees/$tourneeId" });
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { has } = usePermissions();
  const canValidate = has("tournees.valider_couts");

  const tourneeQ = useQuery({
    queryKey: ["tournee", tourneeId],
    queryFn: async (): Promise<Tournee | null> => {
      const { data, error } = await supabase
        .from("tournees")
        .select(
          "tournee_id,reference,date_tournee,responsable_nom,chauffeur_nom,vehicule_id,statut,notes,cout_carburant,cout_peages,cout_repas,cout_expeditions,cout_manutentions,cout_autres,cout_livraison,type_tournee,cout_total,nb_colis,nb_cartons,nb_clients,cloture_mode,cloture_at,cloture_by,validation_statut,validation_at,validation_commentaire,mode_reglement",
        )
        .eq("tournee_id", tourneeId)
        .maybeSingle();
      if (error) throw error;
      return (data as Tournee | null) ?? null;
    },
  });

  const [dateDispo, setDateDispo] = useState<string>(() => new Date().toISOString().slice(0, 10));

  const affectesQ = useQuery({
    queryKey: ["tournee-colis-affectes", tourneeId],
    queryFn: async (): Promise<ColisRow[]> => {
      const { data, error } = await supabase
        .from("colis")
        .select(
          "colis_id,reference,nb_cartons,commande_id,destinataire,ville_livraison,quartier,livreur_nom",
        )
        .eq("tournee_id" as never, tourneeId as never)
        .order("reference");
      if (error) throw error;
      return (data ?? []) as ColisRow[];
    },
  });

  const dispoQ = useQuery({
    queryKey: ["tournee-colis-dispo", dateDispo],
    queryFn: async (): Promise<ColisRow[]> => {
      const { data, error } = await supabase
        .from("colis")
        .select(
          "colis_id,reference,nb_cartons,commande_id,destinataire,ville_livraison,quartier,livreur_nom",
        )
        .is("tournee_id", null)
        .eq("statut_logistique", "prepare")
        .eq("date_colisage", dateDispo)
        .order("date_colisage", { ascending: false })
        .limit(500);
      if (error) throw error;
      return (data ?? []) as ColisRow[];
    },
  });

  const cmdIds = useMemo(() => {
    const set = new Set<string>();
    for (const r of affectesQ.data ?? []) if (r.commande_id) set.add(r.commande_id);
    for (const r of dispoQ.data ?? []) if (r.commande_id) set.add(r.commande_id);
    return Array.from(set);
  }, [affectesQ.data, dispoQ.data]);
  const cmdQ = useQuery({
    queryKey: ["commandes-for-edit-tournee", cmdIds],
    enabled: cmdIds.length > 0,
    queryFn: async (): Promise<CommandeRow[]> => {
      const { data, error } = await supabase
        .from("commandes")
        .select("commande_id,client_id,client_nom")
        .in("commande_id", cmdIds);
      if (error) throw error;
      return (data ?? []) as CommandeRow[];
    },
  });
  const clientByCmd = useMemo(() => {
    const m = new Map<string, CommandeRow>();
    for (const r of cmdQ.data ?? []) m.set(r.commande_id, r);
    return m;
  }, [cmdQ.data]);

  const vehQ = useQuery({
    queryKey: ["vehicules-list"],
    queryFn: async (): Promise<Vehicule[]> => {
      const { data, error } = await supabase
        .from("vehicules")
        .select("vehicule_id,immatriculation")
        .order("immatriculation");
      if (error) throw error;
      return (data ?? []) as Vehicule[];
    },
  });

  const auditQ = useQuery({
    queryKey: ["tournee-audit", tourneeId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("couts_logistiques_audit")
        .select("audit_id, action, actor_email, commentaire, created_at")
        .eq("tournee_id", tourneeId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as Array<{
        audit_id: string;
        action: string;
        actor_email: string | null;
        commentaire: string | null;
        created_at: string;
      }>;
    },
  });

  const [form, setForm] = useState<Tournee | null>(null);
  const [toRemove, setToRemove] = useState<Set<string>>(new Set());
  const [toAdd, setToAdd] = useState<Set<string>>(new Set());
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [filterDispo, setFilterDispo] = useState("");
  const [closing, setClosing] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);

  useEffect(() => {
    if (tourneeQ.data && !form) setForm(tourneeQ.data);
  }, [tourneeQ.data, form]);

  const setField = <K extends keyof Tournee>(k: K, v: Tournee[K]) =>
    setForm((f) => (f ? { ...f, [k]: v } : f));

  const coutTotal = useMemo(() => {
    if (!form) return 0;
    return COST_FIELDS.reduce((s, c) => s + (Number(form[c.key]) || 0), 0);
  }, [form]);

  const affectes = affectesQ.data ?? [];
  const dispo = dispoQ.data ?? [];
  const dispoFiltered = useMemo(() => {
    const f = filterDispo.trim().toLowerCase();
    if (!f) return dispo;
    return dispo.filter((c) => {
      const cli = c.commande_id ? (clientByCmd.get(c.commande_id)?.client_nom ?? "") : "";
      return (
        (c.reference ?? "").toLowerCase().includes(f) ||
        (c.destinataire ?? "").toLowerCase().includes(f) ||
        (c.ville_livraison ?? "").toLowerCase().includes(f) ||
        cli.toLowerCase().includes(f)
      );
    });
  }, [dispo, filterDispo, clientByCmd]);

  // Totaux projetés (après ajout/retrait)
  const totals = useMemo(() => {
    const kept = affectes.filter((c) => !toRemove.has(c.colis_id));
    const added = dispo.filter((c) => toAdd.has(c.colis_id));
    const all = [...kept, ...added];
    // Règle métier : 1 commande = 1 colis (avec N cartons).
    // Chaque ligne de la table `colis` = 1 carton physique.
    const nb_cartons = all.length;
    const commandeIds = new Set<string>();
    for (const r of all) if (r.commande_id) commandeIds.add(r.commande_id);
    const nb_colis = commandeIds.size;
    const clientIds = new Set<string>();
    for (const r of all) {
      if (!r.commande_id) continue;
      const cid = clientByCmd.get(r.commande_id)?.client_id;
      if (cid) clientIds.add(cid);
    }
    return { nb_colis, nb_cartons, nb_clients: clientIds.size };
  }, [affectes, dispo, toRemove, toAdd, clientByCmd]);

  const toggleRemove = (id: string) =>
    setToRemove((prev) => {
      const s = new Set(prev);
      if (s.has(id)) s.delete(id);
      else s.add(id);
      return s;
    });
  const toggleAdd = (id: string) =>
    setToAdd((prev) => {
      const s = new Set(prev);
      if (s.has(id)) s.delete(id);
      else s.add(id);
      return s;
    });

  const save = async () => {
    if (!form) return;
    setSaving(true);
    try {
      const payload: Record<string, unknown> = {
        reference: form.reference,
        date_tournee: form.date_tournee,
        responsable_nom: form.responsable_nom,
        chauffeur_nom: form.chauffeur_nom,
        vehicule_id: form.vehicule_id || null,
        statut: form.statut,
        notes: form.notes,
        cout_carburant: Number(form.cout_carburant) || 0,
        cout_peages: Number(form.cout_peages) || 0,
        cout_repas: Number(form.cout_repas) || 0,
        cout_expeditions: Number(form.cout_expeditions) || 0,
        cout_manutentions: Number(form.cout_manutentions) || 0,
        cout_autres: Number(form.cout_autres) || 0,
        cout_livraison: Number(form.cout_livraison) || 0,
        type_tournee: form.type_tournee || "livraison",
        nb_colis: totals.nb_colis,
        nb_cartons: totals.nb_cartons,
        nb_clients: totals.nb_clients,
      };
      const { error } = await supabase
        .from("tournees")
        .update(payload as never)
        .eq("tournee_id", tourneeId);
      if (error) throw error;

      if (toRemove.size) {
        const { error: rmErr } = await supabase
          .from("colis")
          .update({ tournee_id: null } as never)
          .in("colis_id", Array.from(toRemove));
        if (rmErr) throw rmErr;
      }
      if (toAdd.size) {
        const { error: addErr } = await supabase
          .from("colis")
          .update({ tournee_id: tourneeId } as never)
          .in("colis_id", Array.from(toAdd));
        if (addErr) throw addErr;
      }

      toast.success("Tournée enregistrée");
      setToRemove(new Set());
      setToAdd(new Set());
      qc.invalidateQueries({ queryKey: ["tournees"] });
      qc.invalidateQueries({ queryKey: ["tournee", tourneeId] });
      qc.invalidateQueries({ queryKey: ["tournee-colis-affectes", tourneeId] });
      qc.invalidateQueries({ queryKey: ["tournee-colis-dispo"] });
      invalidateColisage(qc);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Erreur inconnue";
      toast.error("Impossible d'enregistrer", { description: msg });
    } finally {
      setSaving(false);
    }
  };

  const doDelete = async (motif: string | null) => {
    setDeleting(true);
    try {
      const { data, error } = await supabase.rpc("supprimer_tournee" as never, {
        _tournee_id: tourneeId,
        _motif: motif ?? "",
      } as never);
      if (error) throw error;
      const s = data as {
        colis_detaches?: number;
        livraisons_detachees?: number;
        livraisons_commande_detachees?: number;
        expeditions_detachees?: number;
        ecriture_lignes_detachees?: number;
        notifications_supprimees?: number;
        tournees_recalculees?: number;
      } | null;
      const parts = s
        ? [
            s.colis_detaches ? `${s.colis_detaches} colis détachés` : null,
            (s.livraisons_detachees ?? 0) + (s.livraisons_commande_detachees ?? 0)
              ? `${(s.livraisons_detachees ?? 0) + (s.livraisons_commande_detachees ?? 0)} livraison(s)`
              : null,
            s.expeditions_detachees ? `${s.expeditions_detachees} expédition(s)` : null,
            s.ecriture_lignes_detachees
              ? `${s.ecriture_lignes_detachees} ligne(s) comptable(s) détachée(s)`
              : null,
            s.notifications_supprimees ? `${s.notifications_supprimees} notif.` : null,
          ].filter(Boolean)
        : [];
      toast.success("Tournée supprimée", {
        description: parts.length ? parts.join(" · ") : undefined,
      });
      setOpenDelete(false);
      qc.invalidateQueries({ queryKey: ["tournees"] });
      qc.invalidateQueries({ queryKey: ["livraisons"] });
      qc.invalidateQueries({ queryKey: ["livraisons-commande"] });
      qc.invalidateQueries({ queryKey: ["livsuivi"] });
      qc.invalidateQueries({ queryKey: ["notifications"] });
      invalidateColisage(qc);
      navigate({ to: "/tournees" });
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Erreur inconnue";
      toast.error("Impossible de supprimer", { description: msg });
    } finally {
      setDeleting(false);
    }
  };

  const cloturer = async () => {
    setClosing(true);
    try {
      // Clôture = validation administrative :
      //   - vérifie les champs obligatoires (chauffeur, véhicule, date, colis),
      //   - crée/actualise le Suivi des livraisons pour chaque colis,
      //   - passe la tournée à `terminee` et enregistre date/mode/auteur.
      // Aucune livraison n'est marquée terminée à cette étape — c'est le
      // module Suivi des livraisons qui gère l'avancement réel ensuite.
      const missing: string[] = [];
      if (!form?.chauffeur_nom?.trim()) missing.push("Chauffeur");
      if (!form?.vehicule_id) missing.push("Véhicule");
      if (!form?.date_tournee) missing.push("Date de départ");
      if ((affectesQ.data ?? []).length === 0) missing.push("Au moins un colis affecté");
      if (missing.length) {
        toast.error("Clôture impossible", {
          description: `Informations manquantes : ${missing.join(", ")}.`,
        });
        setClosing(false);
        return;
      }

      const { data: updated, error } = await supabase.rpc("cloturer_tournee" as never, {
        _tournee_id: tourneeId,
      } as never);
      if (error) {
        const parts = [
          error.message,
          (error as { details?: string }).details,
          (error as { hint?: string }).hint,
        ]
          .filter(Boolean)
          .join(" — ");
        throw new Error(parts || "Échec de la clôture");
      }
      const row = (updated as Partial<Tournee> | null) ?? null;
      toast.success("Tournée clôturée", {
        description: "Suivi des livraisons créé — le chauffeur peut partir.",
      });
      qc.invalidateQueries({ queryKey: ["tournees"] });
      qc.invalidateQueries({ queryKey: ["tournee", tourneeId] });
      qc.invalidateQueries({ queryKey: ["livsuivi"] });
      qc.invalidateQueries({ queryKey: ["livsuivi-commandes"] });
      setForm((f) =>
        f
          ? {
              ...f,
              statut: "terminee",
              cloture_mode: row?.cloture_mode ?? "manuelle",
              cloture_at: row?.cloture_at ?? new Date().toISOString(),
              cloture_by: row?.cloture_by ?? f.cloture_by,
            }
          : f,
      );
    } catch (e) {
      const msg =
        e instanceof Error
          ? e.message
          : typeof e === "object" && e !== null
            ? [
                (e as { message?: string }).message,
                (e as { details?: string }).details,
                (e as { hint?: string }).hint,
                (e as { code?: string }).code ? `(code ${(e as { code?: string }).code})` : "",
              ]
                .filter(Boolean)
                .join(" — ") || JSON.stringify(e)
            : "Erreur inconnue";
      toast.error("Impossible de clôturer", { description: msg });
    } finally {
      setClosing(false);
    }
  };

  if (tourneeQ.isLoading || !form) {
    return (
      <div className="flex items-center justify-center py-16 text-muted-foreground">
        <Loader2 className="h-4 w-4 animate-spin mr-2" /> Chargement…
      </div>
    );
  }
  if (!tourneeQ.data) {
    return <div className="p-8 text-sm text-muted-foreground">Tournée introuvable.</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="sm" onClick={() => navigate({ to: "/tournees" })}>
            <ArrowLeft className="h-4 w-4 mr-1.5" /> Retour
          </Button>
          <div className="flex items-center gap-2">
            <Navigation className="h-5 w-5 text-primary" />
            <div>
              <h1 className="text-lg font-semibold leading-none">
                Tournée <span className="font-mono text-primary">{form.reference}</span>
              </h1>
              <p className="text-xs text-muted-foreground mt-1">
                Gérer les colis affectés, les coûts et le statut de la tournée.
              </p>
              {form.statut === "terminee" && form.cloture_mode && (
                <div className="mt-1.5 flex items-center gap-2">
                  <Badge
                    className={
                      form.cloture_mode === "auto"
                        ? "bg-emerald-600 hover:bg-emerald-600"
                        : "bg-sky-600 hover:bg-sky-600"
                    }
                  >
                    {form.cloture_mode === "auto"
                      ? "Clôture auto (tous colis livrés)"
                      : "Clôture manuelle"}
                  </Badge>
                  {form.cloture_at && (
                    <span className="text-[11px] text-muted-foreground">
                      le {new Date(form.cloture_at).toLocaleString("fr-FR")}
                    </span>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {form.statut !== "terminee" && form.statut !== "annulee" && (
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button variant="outline" size="sm" disabled={closing}>
                  <CheckCircle2 className="h-4 w-4 mr-1.5" /> Clôturer
                </Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Clôturer la tournée ?</AlertDialogTitle>
                  <AlertDialogDescription>
                    Le statut passera à « Terminée ». La clôture n'est autorisée que si la
                    tournée est validée (statut « En cours »), que les informations obligatoires
                    (chauffeur, véhicule, date, dépôt) sont renseignées, et que toutes les
                    livraisons prévues ont été finalisées (livrée, expédiée, retirée ou annulée).
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Annuler</AlertDialogCancel>
                  <AlertDialogAction onClick={cloturer}>Confirmer</AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          )}
          <Can permission="tournees.supprimer">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setOpenDelete(true)}
              disabled={deleting}
            >
              <Trash2 className="h-4 w-4 mr-1.5" /> Supprimer
            </Button>
          </Can>
          <ConfirmDeleteDialog
            open={openDelete}
            onOpenChange={setOpenDelete}
            entityLabel="cette tournée"
            entityName={form.reference}
            description="La tournée sera supprimée définitivement. Les colis, livraisons, expéditions et lignes comptables rattachés seront automatiquement détachés."
            consequences={[
              "Colis affectés détachés (statut colisage conservé)",
              "Livraisons et livraisons de commande détachées",
              "Expéditions rattachées détachées",
              "Lignes d'écriture comptable détachées",
              "Notifications liées supprimées",
              "Recalcul automatique des tournées restantes de la même date",
            ]}
            motifRequired
            requireTyping="SUPPRIMER"
            pending={deleting}
            onConfirm={(motif) => void doDelete(motif)}
          />
          <Button onClick={save} disabled={saving}>
            {saving ? (
              <Loader2 className="h-4 w-4 mr-1.5 animate-spin" />
            ) : (
              <Save className="h-4 w-4 mr-1.5" />
            )}
            Enregistrer
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <div className="xl:col-span-2 space-y-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm flex items-center gap-2">
                Colis affectés
                <Badge variant="secondary">{affectes.length}</Badge>
                {toRemove.size > 0 && (
                  <Badge variant="destructive">-{toRemove.size} à retirer</Badge>
                )}
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <ColisTable
                rows={affectes}
                clientByCmd={clientByCmd}
                actionHeader="Retirer"
                selected={toRemove}
                onToggle={toggleRemove}
                emptyLabel="Aucun colis affecté."
              />
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between gap-2">
                <CardTitle className="text-sm flex items-center gap-2">
                  Ajouter des colis prêts non affectés
                  <Badge variant="secondary">{dispoFiltered.length}</Badge>
                  {toAdd.size > 0 && (
                    <Badge className="bg-emerald-600">+{toAdd.size} à ajouter</Badge>
                  )}
                </CardTitle>
                <div className="flex items-center gap-2">
                  <Input
                    placeholder="Filtrer…"
                    value={filterDispo}
                    onChange={(e) => setFilterDispo(e.target.value)}
                    className="h-8 w-56"
                  />
                </div>
              </div>
              <div className="pt-2">
                <DateColisPicker
                  value={dateDispo}
                  onChange={setDateDispo}
                  colisCount={dispoQ.data?.length ?? 0}
                />
              </div>
            </CardHeader>
            <CardContent className="p-0">
              <ColisTable
                rows={dispoFiltered}
                clientByCmd={clientByCmd}
                actionHeader="Ajouter"
                selected={toAdd}
                onToggle={toggleAdd}
                emptyLabel="Aucun colis prêt disponible."
                actionIcon={<Plus className="h-3.5 w-3.5" />}
              />
            </CardContent>
          </Card>
        </div>

        <div className="space-y-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Récapitulatif temps réel</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-3 gap-2 text-center">
              <Stat label="Colis" value={totals.nb_colis} />
              <Stat label="Cartons" value={totals.nb_cartons} />
              <Stat label="Clients" value={totals.nb_clients} />
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Journal d'événements</CardTitle>
            </CardHeader>
            <CardContent className="text-xs space-y-2">
              <TimelineRow
                label="Statut actuel"
                value={STATUTS.find((s) => s.value === form.statut)?.label ?? form.statut}
              />
              {form.statut === "terminee" && (
                <TimelineRow
                  label={form.cloture_mode === "auto" ? "Clôture auto" : "Clôture manuelle"}
                  value={
                    <>
                      {form.cloture_at
                        ? new Date(form.cloture_at).toLocaleString("fr-FR")
                        : "date inconnue"}
                      <div className="text-[10px] text-muted-foreground">
                        {form.cloture_mode === "auto"
                          ? "Système — tous les colis livrés"
                          : form.cloture_by
                            ? `Par utilisateur ${form.cloture_by.slice(0, 8)}…`
                            : "Auteur inconnu"}
                        <span className="ml-1">· Tournée {form.reference}</span>
                      </div>
                    </>
                  }
                />
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Informations tournée</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <Field label="Référence">
                <Input
                  value={form.reference}
                  onChange={(e) => setField("reference", e.target.value)}
                />
              </Field>
              <Field label="Date">
                <Input
                  type="date"
                  value={form.date_tournee ?? ""}
                  onChange={(e) => setField("date_tournee", e.target.value || null)}
                />
              </Field>
              <Field label="Responsable">
                <Input
                  value={form.responsable_nom ?? ""}
                  onChange={(e) => setField("responsable_nom", e.target.value)}
                />
              </Field>
              <Field label="Chauffeur">
                <Input
                  value={form.chauffeur_nom ?? ""}
                  onChange={(e) => setField("chauffeur_nom", e.target.value)}
                />
              </Field>
              <Field label="Véhicule">
                <Select
                  value={form.vehicule_id || "__none"}
                  onValueChange={(v) => setField("vehicule_id", v === "__none" ? null : v)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Sélectionner…" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__none">— Aucun —</SelectItem>
                    {(vehQ.data ?? []).map((v) => (
                      <SelectItem key={v.vehicule_id} value={v.vehicule_id}>
                        {v.immatriculation ?? v.vehicule_id}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              <Field label="Statut">
                <Select value={form.statut} onValueChange={(v) => setField("statut", v)}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {STATUTS.map((s) => (
                      <SelectItem key={s.value} value={s.value}>
                        {s.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              <Field label="Type de tournée">
                <Select
                  value={form.type_tournee ?? "livraison"}
                  onValueChange={(v) => setField("type_tournee", v)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="livraison">Livraison</SelectItem>
                    <SelectItem value="expedition">Expédition</SelectItem>
                    <SelectItem value="mixte">Mixte</SelectItem>
                  </SelectContent>
                </Select>
              </Field>
              <Field label="Notes">
                <Textarea
                  rows={2}
                  value={form.notes ?? ""}
                  onChange={(e) => setField("notes", e.target.value)}
                />
              </Field>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Coûts (FCFA)</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              {(() => {
                const vs = form.validation_statut ?? "en_attente";
                const locked =
                  !canValidate && (vs === "valide" || vs === "decaisse" || vs === "refuse");
                return (
                  <>
                    {vs !== "en_attente" && (
                      <div className="text-[11px] rounded bg-muted/40 border px-2 py-1">
                        Statut : <b>{vs}</b>
                        {locked && " — édition verrouillée"}
                      </div>
                    )}
                    {COST_FIELDS.map((c) => (
                      <Field key={String(c.key)} label={c.label}>
                        <Input
                          type="number"
                          value={Number(form[c.key] ?? 0)}
                          disabled={locked}
                          onChange={(e) =>
                            setField(c.key, (Number(e.target.value) || 0) as Tournee[typeof c.key])
                          }
                        />
                      </Field>
                    ))}
                  </>
                );
              })()}
              <div className="flex items-center justify-between pt-2 border-t text-sm font-medium">
                <span>Total</span>
                <span className="tabular-nums">{coutTotal.toLocaleString("fr-FR")}</span>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Historique / Audit</CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <div className="max-h-72 overflow-y-auto divide-y text-xs">
                {(auditQ.data ?? []).length === 0 ? (
                  <div className="p-3 text-muted-foreground">Aucun événement.</div>
                ) : (
                  (auditQ.data ?? []).map((e) => (
                    <div key={e.audit_id} className="p-2">
                      <div className="flex items-center justify-between">
                        <span className="font-medium capitalize">{e.action}</span>
                        <span className="text-muted-foreground">
                          {new Date(e.created_at).toLocaleString("fr-FR")}
                        </span>
                      </div>
                      <div className="text-muted-foreground">{e.actor_email ?? "—"}</div>
                      {e.commentaire && <div className="mt-1">{e.commentaire}</div>}
                    </div>
                  ))
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}

function ColisTable({
  rows,
  clientByCmd,
  actionHeader,
  selected,
  onToggle,
  emptyLabel,
  actionIcon,
}: {
  rows: ColisRow[];
  clientByCmd: Map<string, CommandeRow>;
  actionHeader: string;
  selected: Set<string>;
  onToggle: (id: string) => void;
  emptyLabel: string;
  actionIcon?: React.ReactNode;
}) {
  if (rows.length === 0) {
    return <div className="py-8 text-center text-sm text-muted-foreground">{emptyLabel}</div>;
  }
  return (
    <div className="overflow-auto max-h-[45vh] border-t">
      <table className="w-full text-xs">
        <thead className="bg-muted/50 sticky top-0">
          <tr>
            <th className="p-2 w-16 text-left">{actionHeader}</th>
            <th className="p-2 text-left">Réf.</th>
            <th className="p-2 text-left">Client</th>
            <th className="p-2 text-left">Destinataire / Ville</th>
            <th className="p-2 text-left">Livreur</th>
            <th className="p-2 text-right">Cartons</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((c) => {
            const cli = c.commande_id ? clientByCmd.get(c.commande_id) : undefined;
            const isSel = selected.has(c.colis_id);
            return (
              <tr
                key={c.colis_id}
                className={`border-t hover:bg-accent/40 cursor-pointer ${isSel ? "bg-accent/30" : ""}`}
                onClick={() => onToggle(c.colis_id)}
              >
                <td className="p-2" onClick={(e) => e.stopPropagation()}>
                  <div className="flex items-center gap-1">
                    <Checkbox checked={isSel} onCheckedChange={() => onToggle(c.colis_id)} />
                    {actionIcon}
                  </div>
                </td>
                <td className="p-2 font-mono">{c.reference ?? "—"}</td>
                <td className="p-2">{cli?.client_nom ?? "—"}</td>
                <td className="p-2">
                  <div>{c.destinataire ?? "—"}</div>
                  <div className="text-muted-foreground">
                    {[c.ville_livraison, c.quartier].filter(Boolean).join(" · ") || "—"}
                  </div>
                </td>
                <td className="p-2">{c.livreur_nom ?? "—"}</td>
                <td className="p-2 text-right">1</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-[9rem_1fr] items-center gap-2">
      <Label className="text-xs text-muted-foreground">{label}</Label>
      {children}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-md border p-2">
      <div className="text-xl font-semibold tabular-nums">{value}</div>
      <div className="text-[10px] uppercase text-muted-foreground">{label}</div>
    </div>
  );
}

function TimelineRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex items-start gap-2 border-l-2 border-primary/40 pl-3 py-1">
      <div className="flex-1">
        <div className="font-medium">{label}</div>
        <div className="text-muted-foreground">{value}</div>
      </div>
    </div>
  );
}
