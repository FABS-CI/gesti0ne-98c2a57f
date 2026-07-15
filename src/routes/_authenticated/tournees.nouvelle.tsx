import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { z } from "zod";
import { fallback, zodValidator } from "@tanstack/zod-adapter";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Loader2, Navigation, Save } from "lucide-react";
import { toast } from "sonner";

import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
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
} from "@/components/ui/alert-dialog";
import { invalidateColisage } from "@/lib/cache-invalidation";
import { finaliserTournee } from "@/lib/livraison-suivi/writes";

const searchSchema = z.object({
  preselect: fallback(z.string(), "").default(""),
  colis: fallback(z.string(), "").default(""),
});

export const Route = createFileRoute("/_authenticated/tournees/nouvelle")({
  validateSearch: zodValidator(searchSchema),
  component: NouvelleTourneePage,
});

type ColisRow = {
  colis_id: string;
  reference: string | null;
  bl_id: string | null;
  numero_carton: number | null;
  nb_cartons: number | null;
  commande_id: string | null;
  destinataire: string | null;
  ville_livraison: string | null;
  quartier: string | null;
  vehicule: string | null;
  livreur_nom: string | null;
  responsable_nom: string | null;
  transporteur: string | null;
  mode_acheminement: string | null;
  date_colisage: string | null;
};

type BLStatusRow = { bl_id: string; statut: string | null };

type Vehicule = { vehicule_id: string; immatriculation: string | null };

type CommandeRow = {
  commande_id: string;
  reference: string | null;
  client_id: string | null;
  client_nom: string | null;
  representant_nom: string | null;
  commercial_nom: string | null;
  total_quantite: number | null;
  depot_id: string | null;
  ville: string | null;
};

type DepotRow = { depot_id: string; nom: string | null };

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

function defaultRef() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const rand = Math.floor(1000 + Math.random() * 9000);
  return `TRN-${y}${m}${day}-${rand}`;
}

const COST_FIELDS: Array<{ key: string; label: string }> = [
  { key: "cout_carburant", label: "Carburant" },
  { key: "cout_peages", label: "Péages" },
  { key: "cout_repas", label: "Repas" },
  { key: "cout_livraison", label: "Frais de livraison" },
  { key: "cout_expeditions", label: "Expéditions" },
  { key: "cout_manutentions", label: "Manutentions" },
  { key: "cout_autres", label: "Autres" },
];

// Le statut d'une nouvelle tournée est toujours "preparee" à la création,
// puis passe à "en_cours" via la RPC `finaliser_tournee` (voir submit()).

function NouvelleTourneePage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { preselect, colis: colisParam } = Route.useSearch();
  // Filtre date optionnel (vide = toutes les dates). Aucun impact sur la
  // requête serveur : on récupère tous les colis « prêts non affectés ».
  const [dateColis, setDateColis] = useState<string>("");
  const [clientFilter, setClientFilter] = useState("");
  const [representantFilter, setRepresentantFilter] = useState("");
  const [villeFilter, setVilleFilter] = useState("");

  // Colis prêts non affectés
  const colisQ = useQuery({
    queryKey: ["colis-prets-non-affectes"],
    queryFn: async (): Promise<ColisRow[]> => {
      const { data, error } = await supabase
        .from("colis")
        .select(
          "colis_id,reference,bl_id,numero_carton,nb_cartons,commande_id,destinataire,ville_livraison,quartier,vehicule,livreur_nom,responsable_nom,transporteur,mode_acheminement,date_colisage",
        )
        .is("tournee_id", null)
        .order("date_colisage", { ascending: false })
        .limit(2000);
      if (error) throw error;
      const colis = (data ?? []) as ColisRow[];
      const blIds = Array.from(new Set(colis.map((c) => c.bl_id).filter((v): v is string => !!v)));
      if (blIds.length === 0) return [];

      const { data: bls, error: blError } = await supabase
        .from("bons_livraison")
        .select("bl_id,statut")
        .in("bl_id", blIds)
        .eq("statut", "colisage_termine");
      if (blError) throw blError;

      const blTermines = new Set(((bls ?? []) as BLStatusRow[]).map((bl) => bl.bl_id));
      return colis.filter((c) => !!c.bl_id && blTermines.has(c.bl_id));
    },
  });

  // Synchronisation temps réel : Colisage → Tournées → Suivi.
  // Toute mutation sur `colis` (fin de colisage, affectation à une tournée)
  // recharge instantanément la liste des colis prêts, sans F5.
  useEffect(() => {
    const ch = supabase
      .channel("nouvelle-tournee-colis-sync")
      .on("postgres_changes", { event: "*", schema: "public", table: "colis" }, () => {
        qc.invalidateQueries({ queryKey: ["colis-prets-non-affectes"] });
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "bons_livraison" }, () => {
        qc.invalidateQueries({ queryKey: ["colis-prets-non-affectes"] });
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "tournees" }, () => {
        qc.invalidateQueries({ queryKey: ["colis-prets-non-affectes"] });
      })
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [qc]);

  const commandeIds = useMemo(
    () =>
      Array.from(
        new Set((colisQ.data ?? []).map((c) => c.commande_id).filter((v): v is string => !!v)),
      ),
    [colisQ.data],
  );
  const cmdQ = useQuery({
    queryKey: ["commandes-for-nouvelle-tournee", commandeIds],
    enabled: commandeIds.length > 0,
    queryFn: async (): Promise<CommandeRow[]> => {
      const { data, error } = await supabase
        .from("commandes")
        .select(
          "commande_id,reference,client_id,client_nom,representant_nom,commercial_nom,total_quantite,depot_id,ville",
        )
        .in("commande_id", commandeIds);
      if (error) throw error;
      return (data ?? []) as CommandeRow[];
    },
  });
  const clientByCmd = useMemo(() => {
    const m = new Map<string, CommandeRow>();
    for (const r of cmdQ.data ?? []) m.set(r.commande_id, r);
    return m;
  }, [cmdQ.data]);

  const depotIds = useMemo(
    () =>
      Array.from(
        new Set(
          (cmdQ.data ?? []).map((c) => c.depot_id).filter((v): v is string => !!v),
        ),
      ),
    [cmdQ.data],
  );
  const depotQ = useQuery({
    queryKey: ["depots-for-nouvelle-tournee", depotIds],
    enabled: depotIds.length > 0,
    queryFn: async (): Promise<DepotRow[]> => {
      const { data, error } = await supabase
        .from("depots")
        .select("depot_id,nom")
        .in("depot_id", depotIds);
      if (error) throw error;
      return (data ?? []) as DepotRow[];
    },
  });
  const depotById = useMemo(() => {
    const m = new Map<string, string>();
    for (const d of depotQ.data ?? []) if (d.nom) m.set(d.depot_id, d.nom);
    return m;
  }, [depotQ.data]);

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

  // Liste complète des dépôts pour le champ obligatoire « Dépôt de départ ».
  const depotsListQ = useQuery({
    queryKey: ["depots-all-for-tournee"],
    queryFn: async (): Promise<DepotRow[]> => {
      const { data, error } = await supabase
        .from("depots")
        .select("depot_id,nom")
        .order("nom");
      if (error) throw error;
      return (data ?? []) as DepotRow[];
    },
  });

  // Sélection
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [presetApplied, setPresetApplied] = useState(false);

  // Application des préselections depuis l'URL (?preselect=all ou ?colis=id1,id2)
  useEffect(() => {
    if (presetApplied) return;
    const rows = colisQ.data;
    if (!rows) return;
    if (colisParam) {
      const wanted = new Set(
        colisParam
          .split(",")
          .map((s: string) => s.trim())
          .filter(Boolean),
      );
      const match = rows.filter((r) => wanted.has(r.colis_id)).map((r) => r.colis_id);
      if (match.length) setSelected(new Set(match));
      setPresetApplied(true);
    } else {
      // Auto-sélection par défaut : tous les colis « Colisage terminé »
      // non encore affectés sont pré-cochés à l'ouverture de « Nouvelle
      // tournée » (`preselect=all` reste supporté pour rétro-compatibilité).
      if (rows.length) setSelected(new Set(rows.map((r) => r.colis_id)));
      setPresetApplied(true);
    }
  }, [colisQ.data, preselect, colisParam, presetApplied]);

  const toggle = (id: string) =>
    setSelected((prev) => {
      const s = new Set(prev);
      if (s.has(id)) s.delete(id);
      else s.add(id);
      return s;
    });
  const allIds = (colisQ.data ?? []).map((c) => c.colis_id);
  const allSelected = allIds.length > 0 && allIds.every((id) => selected.has(id));
  const toggleAll = () => setSelected(allSelected ? new Set() : new Set(allIds));

  // Filtre libre (recherche globale)
  const [filter, setFilter] = useState("");
  const rows = useMemo(() => {
    const f = filter.trim().toLowerCase();
    const cf = clientFilter.trim().toLowerCase();
    const rf = representantFilter.trim().toLowerCase();
    const vf = villeFilter.trim().toLowerCase();
    const all = colisQ.data ?? [];
    return all.filter((c) => {
      const cmd = c.commande_id ? clientByCmd.get(c.commande_id) : undefined;
      const cli = cmd?.client_nom ?? "";
      const rep = (cmd?.representant_nom ?? cmd?.commercial_nom ?? "").toLowerCase();
      const ville = (c.ville_livraison ?? cmd?.ville ?? "").toLowerCase();
      if (dateColis && (c.date_colisage ?? "").slice(0, 10) !== dateColis) return false;
      if (cf && !cli.toLowerCase().includes(cf) && !(cmd?.client_id ?? "").toLowerCase().includes(cf))
        return false;
      if (rf && !rep.includes(rf)) return false;
      if (vf && !ville.includes(vf)) return false;
      if (!f) return true;
      return (
        (c.reference ?? "").toLowerCase().includes(f) ||
        (c.destinataire ?? "").toLowerCase().includes(f) ||
        ville.includes(f) ||
        (c.livreur_nom ?? "").toLowerCase().includes(f) ||
        rep.includes(f) ||
        cli.toLowerCase().includes(f)
      );
    });
  }, [colisQ.data, clientByCmd, filter, clientFilter, representantFilter, villeFilter, dateColis]);

  // Totaux temps réel (basés sur la sélection)
  const selectedRows = useMemo(
    () => (colisQ.data ?? []).filter((c) => selected.has(c.colis_id)),
    [colisQ.data, selected],
  );
  const totals = useMemo(() => {
    // Règle métier : 1 commande = 1 colis (avec N cartons).
    // Chaque ligne de la table `colis` = 1 carton physique.
    const nb_cartons = selectedRows.length;
    const commandeIds = new Set<string>();
    for (const r of selectedRows) if (r.commande_id) commandeIds.add(r.commande_id);
    const nb_colis = commandeIds.size;
    const clientIds = new Set<string>();
    for (const r of selectedRows) {
      if (!r.commande_id) continue;
      const cid = clientByCmd.get(r.commande_id)?.client_id;
      if (cid) clientIds.add(cid);
    }
    return { nb_colis, nb_cartons, nb_clients: clientIds.size };
  }, [selectedRows, clientByCmd]);

  // Formulaire tournée
  const [form, setForm] = useState({
    reference: defaultRef(),
    date_tournee: todayISO(),
    heure_depart: "08:00",
    depot_depart_id: "" as string,
    responsable_nom: "",
    chauffeur_nom: "",
    vehicule_id: "" as string,
    statut: "preparee",
    type_tournee: "livraison",
    notes: "",
  });
  const [costs, setCosts] = useState<Record<string, number>>({
    cout_carburant: 0,
    cout_peages: 0,
    cout_repas: 0,
    cout_livraison: 0,
    cout_expeditions: 0,
    cout_manutentions: 0,
    cout_autres: 0,
  });
  const coutTotal = useMemo(
    () => Object.values(costs).reduce((s, v) => s + (Number(v) || 0), 0),
    [costs],
  );

  // Pré-remplissage à partir des colis chargés (le plus fréquent)
  useEffect(() => {
    const rows = colisQ.data ?? [];
    if (!rows.length) return;
    const mode = (k: keyof ColisRow) => {
      const counts = new Map<string, number>();
      for (const r of rows) {
        const v = String(r[k] ?? "").trim();
        if (!v) continue;
        counts.set(v, (counts.get(v) ?? 0) + 1);
      }
      let best = "";
      let bestN = 0;
      for (const [k2, n] of counts)
        if (n > bestN) {
          best = k2;
          bestN = n;
        }
      return best;
    };
    setForm((f) => ({
      ...f,
      chauffeur_nom: f.chauffeur_nom || mode("livreur_nom"),
      responsable_nom: f.responsable_nom || mode("responsable_nom"),
    }));
  }, [colisQ.data]);

  useEffect(() => {
    if (form.vehicule_id) return;
    const vehs = vehQ.data ?? [];
    const rows = colisQ.data ?? [];
    if (!vehs.length || !rows.length) return;
    const counts = new Map<string, number>();
    for (const r of rows) {
      const v = (r.vehicule ?? "").trim();
      if (!v) continue;
      counts.set(v, (counts.get(v) ?? 0) + 1);
    }
    let bestImmat = "";
    let bestN = 0;
    for (const [k, n] of counts)
      if (n > bestN) {
        bestImmat = k;
        bestN = n;
      }
    if (!bestImmat) return;
    const match = vehs.find(
      (v) => (v.immatriculation ?? "").toLowerCase() === bestImmat.toLowerCase(),
    );
    if (match) setForm((f) => ({ ...f, vehicule_id: match.vehicule_id }));
  }, [vehQ.data, colisQ.data, form.vehicule_id]);

  const [saving, setSaving] = useState(false);
  // Champs strictement obligatoires pour valider une tournée dans le nouveau
  // workflow (Colisage → Tournée → Suivi). Un manquement bloque la validation
  // et affiche la liste précise des informations à compléter.
  const missingFields = useMemo(() => {
    const missing: string[] = [];
    if (!form.reference.trim()) missing.push("Référence");
    if (!form.chauffeur_nom.trim()) missing.push("Chauffeur");
    if (!form.vehicule_id) missing.push("Véhicule");
    if (!form.date_tournee) missing.push("Date de départ");
    if (!form.heure_depart) missing.push("Heure de départ");
    if (!form.depot_depart_id) missing.push("Dépôt de départ");
    if (selected.size === 0) missing.push("Au moins un colis");
    return missing;
  }, [form, selected.size]);
  const canSave = missingFields.length === 0 && !saving;
  const [confirmOpen, setConfirmOpen] = useState(false);

  const submit = async () => {
    if (!canSave) return;
    setSaving(true);
    try {
      const payload: Record<string, unknown> = {
        reference: form.reference.trim(),
        date_tournee: form.date_tournee,
        heure_depart: form.heure_depart,
        depot_depart_id: form.depot_depart_id,
        responsable_nom: form.responsable_nom || null,
        chauffeur_nom: form.chauffeur_nom || null,
        vehicule_id: form.vehicule_id || null,
        // La création laisse la tournée en brouillon ("preparee") ; le passage
        // à "en_cours" (validation) est fait par la RPC `finaliser_tournee`
        // qui crée aussi les lignes de suivi de livraison correspondantes.
        statut: "preparee",
        type_tournee: form.type_tournee,
        notes: form.notes || null,
        nb_colis: totals.nb_colis,
        nb_cartons: totals.nb_cartons,
        nb_clients: totals.nb_clients,
        ...costs,
      };
      const { data: created, error } = await supabase
        .from("tournees")
        .insert(payload as never)
        .select("tournee_id")
        .single();
      if (error) throw error;
      const tourneeId = (created as { tournee_id: string }).tournee_id;

      const ids = Array.from(selected);
      const { error: upErr } = await supabase
        .from("colis")
        .update({ tournee_id: tourneeId } as never)
        .in("colis_id", ids);
      if (upErr) throw upErr;

      // Validation immédiate : crée les lignes de suivi de livraison
      // rattachées à cette tournée et passe la tournée à `en_cours`.
      await finaliserTournee(tourneeId);

      toast.success("Tournée validée", {
        description: `${totals.nb_colis} colis affectés à ${form.reference}. Le suivi de livraison a été ouvert.`,
      });
      qc.invalidateQueries({ queryKey: ["tournees"] });
      invalidateColisage(qc);
      qc.invalidateQueries({ queryKey: ["colis-prets-non-affectes"] });
      qc.invalidateQueries({ queryKey: ["livsuivi"] });
      navigate({ to: "/tournees" });
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Erreur inconnue";
      toast.error("Impossible de créer la tournée", { description: msg });
    } finally {
      setSaving(false);
      setConfirmOpen(false);
    }
  };

  const loading = colisQ.isLoading || vehQ.isLoading;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="sm" onClick={() => navigate({ to: "/tournees" })}>
            <ArrowLeft className="h-4 w-4 mr-1.5" />
            Retour
          </Button>
          <div className="flex items-center gap-2">
            <Navigation className="h-5 w-5 text-primary" />
            <div>
              <h1 className="text-lg font-semibold leading-none">Nouvelle tournée</h1>
              <p className="text-xs text-muted-foreground mt-1">
                Sélectionnez les colis prêts non affectés à charger dans la tournée.
              </p>
            </div>
          </div>
        </div>
        <div className="flex flex-col items-end gap-1">
          <Button onClick={() => setConfirmOpen(true)} disabled={!canSave}>
            {saving ? (
              <Loader2 className="h-4 w-4 mr-1.5 animate-spin" />
            ) : (
              <Save className="h-4 w-4 mr-1.5" />
            )}
            Valider la tournée
          </Button>
          {missingFields.length > 0 && !saving && (
            <p className="text-[11px] text-destructive text-right max-w-xs">
              À compléter : {missingFields.join(", ")}.
            </p>
          )}
        </div>
      </div>

      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmer la création de cette tournée ?</AlertDialogTitle>
            <AlertDialogDescription>
              Après validation, les {totals.nb_colis} colis sélectionnés seront
              affectés à la tournée <strong>{form.reference}</strong> et
              deviendront disponibles dans le module Suivi de livraison. Cette
              opération est définitive : un colis affecté ne peut plus être
              déplacé vers une autre tournée.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={saving}>Annuler</AlertDialogCancel>
            <AlertDialogAction onClick={submit} disabled={saving}>
              {saving ? (
                <>
                  <Loader2 className="h-4 w-4 mr-1.5 animate-spin" />
                  Validation…
                </>
              ) : (
                "Confirmer"
              )}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <Card className="xl:col-span-2">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between gap-2">
              <CardTitle className="text-sm">
                Colis prêts non affectés
                <Badge variant="secondary" className="ml-2">
                  {rows.length}
                </Badge>
              </CardTitle>
              <div className="flex items-center gap-2">
                <Input
                  placeholder="Filtrer…"
                  value={filter}
                  onChange={(e) => setFilter(e.target.value)}
                  className="h-8 w-56"
                />
                <Button size="sm" variant="outline" onClick={toggleAll} disabled={!rows.length}>
                  {allSelected ? "Tout désélectionner" : "Tout sélectionner"}
                </Button>
              </div>
            </div>
            <div className="pt-2">
              <div className="grid grid-cols-1 sm:grid-cols-4 gap-2">
                <Input
                  placeholder="Client (nom ou code)"
                  value={clientFilter}
                  onChange={(e) => setClientFilter(e.target.value)}
                  className="h-8"
                />
                <Input
                  placeholder="Représentant"
                  value={representantFilter}
                  onChange={(e) => setRepresentantFilter(e.target.value)}
                  className="h-8"
                />
                <Input
                  placeholder="Ville"
                  value={villeFilter}
                  onChange={(e) => setVilleFilter(e.target.value)}
                  className="h-8"
                />
                <div className="flex items-center gap-1">
                  <Input
                    type="date"
                    value={dateColis}
                    onChange={(e) => setDateColis(e.target.value)}
                    className="h-8"
                    title="Filtre date (optionnel)"
                  />
                  {dateColis && (
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      className="h-8 px-2"
                      onClick={() => setDateColis("")}
                    >
                      ×
                    </Button>
                  )}
                </div>
              </div>
              <p className="mt-1 text-[11px] text-muted-foreground">
                Tous les colis dont le colisage est terminé et non affectés à une tournée sont
                affichés en temps réel. La date est un filtre optionnel.
              </p>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {loading ? (
              <div className="flex items-center justify-center py-10 text-muted-foreground">
                <Loader2 className="h-4 w-4 animate-spin mr-2" /> Chargement…
              </div>
            ) : rows.length === 0 ? (
              <div className="py-10 text-center text-sm text-muted-foreground">
                Aucun colis prêt non affecté. Préparez un colisage d'abord.
              </div>
            ) : (
              <div className="overflow-auto max-h-[60vh] border-t">
                <table className="w-full text-xs">
                  <thead className="bg-muted/50 sticky top-0">
                    <tr>
                      <th className="p-2 w-8"></th>
                      <th className="p-2 text-left">N° colis</th>
                      <th className="p-2 text-left">Commande</th>
                      <th className="p-2 text-left">Client</th>
                      <th className="p-2 text-left">Représentant</th>
                      <th className="p-2 text-left">Ville</th>
                      <th className="p-2 text-right">Cartons</th>
                      <th className="p-2 text-right">Qté</th>
                      <th className="p-2 text-left">Date prép.</th>
                      <th className="p-2 text-left">Magasin</th>
                      <th className="p-2 text-left">Responsable</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((c) => {
                      const cli = c.commande_id ? clientByCmd.get(c.commande_id) : undefined;
                      const isSel = selected.has(c.colis_id);
                      const rep = cli?.representant_nom ?? cli?.commercial_nom ?? "—";
                      const depotNom = cli?.depot_id ? (depotById.get(cli.depot_id) ?? "—") : "—";
                      const ville = c.ville_livraison ?? cli?.ville ?? "—";
                      return (
                        <tr
                          key={c.colis_id}
                          className={`border-t hover:bg-accent/40 cursor-pointer ${isSel ? "bg-accent/30" : ""}`}
                          onClick={() => toggle(c.colis_id)}
                        >
                          <td className="p-2" onClick={(e) => e.stopPropagation()}>
                            <Checkbox checked={isSel} onCheckedChange={() => toggle(c.colis_id)} />
                          </td>
                          <td className="p-2 font-mono">{c.reference ?? "—"}</td>
                          <td className="p-2 font-mono">{cli?.reference ?? "—"}</td>
                          <td className="p-2">{cli?.client_nom ?? "—"}</td>
                          <td className="p-2">{rep}</td>
                          <td className="p-2">{ville}</td>
                          <td className="p-2 text-right">1</td>
                          <td className="p-2 text-right">{cli?.total_quantite ?? "—"}</td>
                          <td className="p-2">
                            {c.date_colisage ? c.date_colisage.slice(0, 10) : "—"}
                          </td>
                          <td className="p-2">{depotNom}</td>
                          <td className="p-2">{c.responsable_nom ?? "—"}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

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
              <CardTitle className="text-sm">Informations tournée</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <Field label="Référence *">
                <Input
                  value={form.reference}
                  onChange={(e) => setForm({ ...form, reference: e.target.value })}
                />
              </Field>
              <Field label="Date">
                <Input
                  type="date"
                  value={form.date_tournee}
                  onChange={(e) => setForm({ ...form, date_tournee: e.target.value })}
                />
              </Field>
              <Field label="Heure de départ *">
                <Input
                  type="time"
                  value={form.heure_depart}
                  onChange={(e) => setForm({ ...form, heure_depart: e.target.value })}
                />
              </Field>
              <Field label="Dépôt de départ *">
                <Select
                  value={form.depot_depart_id || "__none"}
                  onValueChange={(v) =>
                    setForm({ ...form, depot_depart_id: v === "__none" ? "" : v })
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Sélectionner…" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__none">— Sélectionner —</SelectItem>
                    {(depotsListQ.data ?? []).map((d) => (
                      <SelectItem key={d.depot_id} value={d.depot_id}>
                        {d.nom ?? d.depot_id}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              <Field label="Responsable logistique">
                <Input
                  value={form.responsable_nom}
                  onChange={(e) => setForm({ ...form, responsable_nom: e.target.value })}
                />
              </Field>
              <Field label="Chauffeur *">
                <Input
                  value={form.chauffeur_nom}
                  onChange={(e) => setForm({ ...form, chauffeur_nom: e.target.value })}
                />
              </Field>
              <Field label="Véhicule *">
                <Select
                  value={form.vehicule_id || "__none"}
                  onValueChange={(v) => setForm({ ...form, vehicule_id: v === "__none" ? "" : v })}
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
              <Field label="Type de tournée">
                <Select
                  value={form.type_tournee}
                  onValueChange={(v) => setForm({ ...form, type_tournee: v })}
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
                  value={form.notes}
                  onChange={(e) => setForm({ ...form, notes: e.target.value })}
                />
              </Field>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Coûts (FCFA)</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              {COST_FIELDS.map((c) => (
                <Field key={c.key} label={c.label}>
                  <Input
                    type="number"
                    inputMode="numeric"
                    value={costs[c.key] ?? 0}
                    onChange={(e) => setCosts({ ...costs, [c.key]: Number(e.target.value) || 0 })}
                  />
                </Field>
              ))}
              <div className="flex items-center justify-between pt-2 border-t text-sm font-medium">
                <span>Total</span>
                <span className="tabular-nums">{coutTotal.toLocaleString("fr-FR")}</span>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
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
