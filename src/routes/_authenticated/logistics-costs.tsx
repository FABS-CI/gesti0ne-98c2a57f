import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  CheckCircle2,
  DollarSign,
  Eye,
  FileDown,
  Filter,
  Printer,
  Undo2,
  XCircle,
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { usePermissions } from "@/hooks/use-permissions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { exportListePDF } from "@/lib/pdf/exportListe";
import { generateRecapCoutsTourneePDF } from "@/lib/pdf/tourneePdf";
import { viewCached } from "@/lib/pdf/actions";

export const Route = createFileRoute("/_authenticated/logistics-costs")({
  component: LogisticsCostsPage,
});

// ---------------------------------------------------------------------------
// Types & constantes
// ---------------------------------------------------------------------------
type TourneeCout = {
  tournee_id: string;
  reference: string;
  date_tournee: string | null;
  chauffeur_nom: string | null;
  responsable_nom: string | null;
  vehicule_id: string | null;
  vehicules?: { immatriculation: string | null } | null;
  statut: string;
  type_tournee: string | null;
  validation_statut: string;
  mode_reglement: string | null;
  validation_at: string | null;
  validation_commentaire: string | null;
  nb_clients: number;
  nb_colis: number;
  nb_cartons: number;
  cout_carburant: number;
  cout_peages: number;
  cout_repas: number;
  cout_manutentions: number;
  cout_livraison: number;
  cout_expeditions: number;
  cout_autres: number;
  cout_total: number | null;
  ecriture_id: string | null;
};

const VALIDATION_STATUTS = [
  { value: "en_attente", label: "En attente de validation", color: "amber" },
  { value: "valide", label: "Validé", color: "blue" },
  { value: "refuse", label: "Refusé", color: "red" },
  { value: "annule", label: "Annulé", color: "gray" },
  { value: "decaisse", label: "Décaissement effectué", color: "green" },
] as const;

const TYPES = [
  { value: "livraison", label: "Livraison" },
  { value: "expedition", label: "Expédition" },
  { value: "mixte", label: "Mixte" },
];

const CATEGORIES: Array<{ key: keyof TourneeCout; label: string }> = [
  { key: "cout_carburant", label: "Carburant" },
  { key: "cout_peages", label: "Péages" },
  { key: "cout_repas", label: "Repas" },
  { key: "cout_manutentions", label: "Manutentions" },
  { key: "cout_livraison", label: "Livraison" },
  { key: "cout_expeditions", label: "Expéditions" },
  { key: "cout_autres", label: "Autres" },
];

function statutMeta(v: string) {
  return VALIDATION_STATUTS.find((s) => s.value === v) ?? VALIDATION_STATUTS[0];
}

function fmtFCFA(n: number | null | undefined): string {
  return Math.round(Number(n ?? 0)).toLocaleString("fr-FR") + " FCFA";
}

function startOf(period: "day" | "week" | "month" | "year"): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  if (period === "day") return d;
  if (period === "week") {
    const day = (d.getDay() + 6) % 7; // lundi = 0
    d.setDate(d.getDate() - day);
    return d;
  }
  if (period === "month") return new Date(d.getFullYear(), d.getMonth(), 1);
  return new Date(d.getFullYear(), 0, 1);
}

// ---------------------------------------------------------------------------
// Composant principal
// ---------------------------------------------------------------------------
function LogisticsCostsPage() {
  const qc = useQueryClient();
  const { has } = usePermissions();
  const canValidate = has("tournees.valider_couts");
  const canCancel = has("tournees.annuler_validation");

  const [f, setF] = useState({
    from: "",
    to: "",
    chauffeur: "",
    responsable: "",
    vehicule: "all",
    statut: "all",
    type: "all",
  });

  const vehQ = useQuery({
    queryKey: ["logistics-vehicules"],
    queryFn: async () => {
      const { data } = await supabase
        .from("vehicules")
        .select("vehicule_id, immatriculation")
        .order("immatriculation");
      return (data ?? []) as Array<{ vehicule_id: string; immatriculation: string | null }>;
    },
  });

  const listQ = useQuery({
    queryKey: ["logistics-costs", f],
    queryFn: async (): Promise<TourneeCout[]> => {
      let q = supabase
        .from("tournees")
        .select(
          "tournee_id, reference, date_tournee, chauffeur_nom, responsable_nom, vehicule_id, vehicules:vehicule_id(immatriculation), statut, type_tournee, validation_statut, mode_reglement, validation_at, validation_commentaire, nb_clients, nb_colis, nb_cartons, cout_carburant, cout_peages, cout_repas, cout_manutentions, cout_livraison, cout_expeditions, cout_autres, cout_total, ecriture_id",
        )
        .gt("cout_total", 0)
        .order("date_tournee", { ascending: false, nullsFirst: false });
      if (f.from) q = q.gte("date_tournee", f.from);
      if (f.to) q = q.lte("date_tournee", f.to);
      if (f.chauffeur) q = q.ilike("chauffeur_nom", `%${f.chauffeur}%`);
      if (f.responsable) q = q.ilike("responsable_nom", `%${f.responsable}%`);
      if (f.vehicule !== "all") q = q.eq("vehicule_id", f.vehicule);
      if (f.statut !== "all") q = q.eq("validation_statut", f.statut);
      if (f.type !== "all") q = q.eq("type_tournee", f.type);
      const { data, error } = await q;
      if (error) throw error;
      return (data ?? []) as unknown as TourneeCout[];
    },
  });

  // Realtime : rafraîchit à chaque changement
  useEffect(() => {
    const ch = supabase
      .channel("logistics-costs-sync")
      .on("postgres_changes", { event: "*", schema: "public", table: "tournees" }, () =>
        qc.invalidateQueries({ queryKey: ["logistics-costs"] }),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [qc]);

  const rows = listQ.data ?? [];

  // KPIs
  const kpis = useMemo(() => {
    const now = new Date();
    const day = startOf("day");
    const week = startOf("week");
    const month = startOf("month");
    const year = startOf("year");
    let tDay = 0,
      tWeek = 0,
      tMonth = 0,
      tYear = 0;
    const byCat: Record<string, number> = Object.fromEntries(CATEGORIES.map((c) => [c.key, 0]));
    let sumClients = 0,
      sumColis = 0,
      sumCartons = 0,
      sumTotal = 0;
    for (const r of rows) {
      const dt = r.date_tournee ? new Date(r.date_tournee) : null;
      const total = Number(r.cout_total ?? 0);
      sumTotal += total;
      sumClients += r.nb_clients ?? 0;
      sumColis += r.nb_colis ?? 0;
      sumCartons += r.nb_cartons ?? 0;
      for (const c of CATEGORIES) byCat[c.key] += Number(r[c.key] ?? 0);
      if (!dt) continue;
      if (dt >= day && dt <= now) tDay += total;
      if (dt >= week) tWeek += total;
      if (dt >= month) tMonth += total;
      if (dt >= year) tYear += total;
    }
    const n = rows.length || 1;
    return {
      tDay,
      tWeek,
      tMonth,
      tYear,
      moyTournee: sumTotal / n,
      moyClient: sumClients ? sumTotal / sumClients : 0,
      moyColis: sumColis ? sumTotal / sumColis : 0,
      moyCarton: sumCartons ? sumTotal / sumCartons : 0,
      byCat,
      sumTotal,
    };
  }, [rows]);

  // Actions
  const [validating, setValidating] = useState<TourneeCout | null>(null);
  const [refusing, setRefusing] = useState<TourneeCout | null>(null);
  const [detail, setDetail] = useState<TourneeCout | null>(null);

  const exportPdf = () => {
    exportListePDF({
      titre: "Coûts logistiques — Récapitulatif",
      filtres: [
        f.from ? `Du ${f.from}` : "Depuis le début",
        f.to ? `au ${f.to}` : "à ce jour",
        f.statut !== "all" ? `Statut : ${statutMeta(f.statut).label}` : "Tous statuts",
        f.type !== "all" ? `Type : ${f.type}` : "Tous types",
      ],
      colonnes: [
        "Tournée",
        "Date",
        "Chauffeur",
        "Véhicule",
        "Type",
        "Colis",
        "Cartons",
        "Total FCFA",
        "Statut",
      ],
      lignes: rows.map((r) => [
        r.reference,
        r.date_tournee ?? "—",
        r.chauffeur_nom ?? "—",
        r.vehicules?.immatriculation ?? "—",
        r.type_tournee ?? "—",
        r.nb_colis,
        r.nb_cartons,
        Math.round(Number(r.cout_total ?? 0)).toLocaleString("fr-FR"),
        statutMeta(r.validation_statut).label,
      ]),
      recap: [
        { label: "Nombre de tournées", valeur: String(rows.length) },
        { label: "Total période", valeur: fmtFCFA(kpis.sumTotal) },
        { label: "Total mois", valeur: fmtFCFA(kpis.tMonth) },
        { label: "Moyenne / tournée", valeur: fmtFCFA(kpis.moyTournee) },
      ],
      filename: "couts-logistiques",
    });
  };

  return (
    <div className="space-y-4 p-4">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <DollarSign className="h-6 w-6" /> Coûts logistiques
          </h1>
          <p className="text-sm text-muted-foreground">
            Consultation, validation comptable et suivi des dépenses des tournées.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={exportPdf} disabled={!rows.length}>
          <FileDown className="mr-2 h-4 w-4" /> Rapport PDF
        </Button>
      </div>

      {/* KPI cards */}
      <div className="grid gap-3 grid-cols-2 md:grid-cols-4">
        <Kpi label="Aujourd'hui" value={fmtFCFA(kpis.tDay)} />
        <Kpi label="Semaine" value={fmtFCFA(kpis.tWeek)} />
        <Kpi label="Mois" value={fmtFCFA(kpis.tMonth)} />
        <Kpi label="Année" value={fmtFCFA(kpis.tYear)} />
        <Kpi label="Moyenne / tournée" value={fmtFCFA(kpis.moyTournee)} />
        <Kpi label="Moyenne / client" value={fmtFCFA(kpis.moyClient)} />
        <Kpi label="Moyenne / colis" value={fmtFCFA(kpis.moyColis)} />
        <Kpi label="Moyenne / carton" value={fmtFCFA(kpis.moyCarton)} />
      </div>

      {/* Répartition par catégorie */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm">Répartition des dépenses par catégorie</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-2 grid-cols-2 md:grid-cols-4 lg:grid-cols-7">
            {CATEGORIES.map((c) => {
              const v = kpis.byCat[c.key] ?? 0;
              const pct = kpis.sumTotal ? Math.round((v / kpis.sumTotal) * 100) : 0;
              return (
                <div key={String(c.key)} className="rounded border p-2 text-xs">
                  <div className="text-muted-foreground">{c.label}</div>
                  <div className="font-semibold tabular-nums">{fmtFCFA(v)}</div>
                  <div className="text-muted-foreground">{pct}%</div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Filtres */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm flex items-center gap-2">
            <Filter className="h-4 w-4" /> Filtres
          </CardTitle>
        </CardHeader>
        <CardContent className="grid gap-3 grid-cols-2 md:grid-cols-4 lg:grid-cols-7">
          <div>
            <label className="text-xs text-muted-foreground">Du</label>
            <Input
              type="date"
              value={f.from}
              onChange={(e) => setF({ ...f, from: e.target.value })}
            />
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Au</label>
            <Input type="date" value={f.to} onChange={(e) => setF({ ...f, to: e.target.value })} />
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Chauffeur</label>
            <Input
              value={f.chauffeur}
              onChange={(e) => setF({ ...f, chauffeur: e.target.value })}
            />
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Responsable</label>
            <Input
              value={f.responsable}
              onChange={(e) => setF({ ...f, responsable: e.target.value })}
            />
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Véhicule</label>
            <Select value={f.vehicule} onValueChange={(v) => setF({ ...f, vehicule: v })}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Tous</SelectItem>
                {(vehQ.data ?? []).map((v) => (
                  <SelectItem key={v.vehicule_id} value={v.vehicule_id}>
                    {v.immatriculation ?? v.vehicule_id}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Statut</label>
            <Select value={f.statut} onValueChange={(v) => setF({ ...f, statut: v })}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Tous</SelectItem>
                {VALIDATION_STATUTS.map((s) => (
                  <SelectItem key={s.value} value={s.value}>
                    {s.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Type</label>
            <Select value={f.type} onValueChange={(v) => setF({ ...f, type: v })}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Tous</SelectItem>
                {TYPES.map((t) => (
                  <SelectItem key={t.value} value={t.value}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Liste */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm">Tournées avec coûts ({rows.length})</CardTitle>
        </CardHeader>
        <CardContent className="overflow-x-auto">
          <table className="w-full border-collapse text-xs">
            <thead>
              <tr className="bg-muted/40 text-left">
                <th className="border p-2">Tournée</th>
                <th className="border p-2">Date</th>
                <th className="border p-2">Chauffeur</th>
                <th className="border p-2">Véhicule</th>
                <th className="border p-2">Type</th>
                <th className="border p-2 text-right">Clients</th>
                <th className="border p-2 text-right">Colis</th>
                <th className="border p-2 text-right">Cartons</th>
                <th className="border p-2 text-right">Total FCFA</th>
                <th className="border p-2">Statut</th>
                <th className="border p-2 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr>
                  <td colSpan={11} className="border p-4 text-center text-muted-foreground">
                    {listQ.isLoading ? "Chargement…" : "Aucun coût enregistré."}
                  </td>
                </tr>
              ) : (
                rows.map((r) => {
                  const meta = statutMeta(r.validation_statut);
                  return (
                    <tr key={r.tournee_id} className="hover:bg-muted/20">
                      <td className="border p-2 font-mono">{r.reference}</td>
                      <td className="border p-2">{r.date_tournee ?? "—"}</td>
                      <td className="border p-2">{r.chauffeur_nom ?? "—"}</td>
                      <td className="border p-2">{r.vehicules?.immatriculation ?? "—"}</td>
                      <td className="border p-2 capitalize">{r.type_tournee ?? "—"}</td>
                      <td className="border p-2 text-right tabular-nums">{r.nb_clients}</td>
                      <td className="border p-2 text-right tabular-nums">{r.nb_colis}</td>
                      <td className="border p-2 text-right tabular-nums">{r.nb_cartons}</td>
                      <td className="border p-2 text-right tabular-nums font-semibold">
                        {Math.round(Number(r.cout_total ?? 0)).toLocaleString("fr-FR")}
                      </td>
                      <td className="border p-2">
                        <Badge variant="outline" className={`text-${meta.color}-700`}>
                          {meta.label}
                        </Badge>
                      </td>
                      <td className="border p-2 text-right">
                        <div className="inline-flex gap-1">
                          <Button aria-label="Voir la tournée" asChild variant="ghost" size="icon" title="Voir la tournée">
                            <Link to="/tournees/$tourneeId" params={{ tourneeId: r.tournee_id }}>
                              <Eye className="h-4 w-4" />
                            </Link>
                          </Button>
                          <Button aria-label="Détail des coûts"
                            variant="ghost"
                            size="icon"
                            title="Détail des coûts"
                            onClick={() => setDetail(r)}
                          >
                            <FileDown className="h-4 w-4" />
                          </Button>
                          {canValidate && r.validation_statut === "en_attente" && (
                            <>
                              <Button aria-label="Valider le décaissement"
                                variant="ghost"
                                size="icon"
                                title="Valider le décaissement"
                                onClick={() => setValidating(r)}
                              >
                                <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                              </Button>
                              <Button aria-label="Refuser"
                                variant="ghost"
                                size="icon"
                                title="Refuser"
                                onClick={() => setRefusing(r)}
                              >
                                <XCircle className="h-4 w-4 text-red-600" />
                              </Button>
                            </>
                          )}
                          {canCancel && r.validation_statut === "decaisse" && (
                            <Button aria-label="Annuler la validation"
                              variant="ghost"
                              size="icon"
                              title="Annuler la validation"
                              onClick={async () => {
                                if (!confirm("Annuler la validation et supprimer l'écriture ?"))
                                  return;
                                const { error } = await supabase.rpc("annuler_validation_tournee", {
                                  _tournee_id: r.tournee_id,
                                  _commentaire: undefined,
                                });
                                if (error) toast.error(error.message);
                                else {
                                  toast.success("Validation annulée");
                                  qc.invalidateQueries({ queryKey: ["logistics-costs"] });
                                }
                              }}
                            >
                              <Undo2 className="h-4 w-4" />
                            </Button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </CardContent>
      </Card>

      <ValidateDialog
        row={validating}
        onClose={() => setValidating(null)}
        onDone={() => qc.invalidateQueries({ queryKey: ["logistics-costs"] })}
      />
      <RefuseDialog
        row={refusing}
        onClose={() => setRefusing(null)}
        onDone={() => qc.invalidateQueries({ queryKey: ["logistics-costs"] })}
      />
      <DetailDialog row={detail} onClose={() => setDetail(null)} />
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <CardContent className="p-3">
        <div className="text-xs text-muted-foreground">{label}</div>
        <div className="text-lg font-bold tabular-nums">{value}</div>
      </CardContent>
    </Card>
  );
}

function DetailDialog({ row, onClose }: { row: TourneeCout | null; onClose: () => void }) {
  if (!row) return null;
  const meta = statutMeta(row.validation_statut);
  const openPdf = () =>
    viewCached(
      `recap-couts-${row.tournee_id}`,
      () => generateRecapCoutsTourneePDF(row.tournee_id),
      {
        title: `Récapitulatif coûts — ${row.reference}`,
        filename: `recap-couts-${row.reference}.pdf`,
      },
    );
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Détail des coûts — {row.reference}</DialogTitle>
        </DialogHeader>
        <div className="space-y-3 text-sm">
          <div className="grid grid-cols-2 gap-2">
            <div>
              <span className="text-muted-foreground">Date : </span>
              {row.date_tournee ?? "—"}
            </div>
            <div>
              <span className="text-muted-foreground">Chauffeur : </span>
              {row.chauffeur_nom ?? "—"}
            </div>
            <div>
              <span className="text-muted-foreground">Responsable : </span>
              {row.responsable_nom ?? "—"}
            </div>
            <div>
              <span className="text-muted-foreground">Véhicule : </span>
              {row.vehicules?.immatriculation ?? "—"}
            </div>
            <div>
              <span className="text-muted-foreground">Type : </span>
              {row.type_tournee ?? "—"}
            </div>
            <div>
              <span className="text-muted-foreground">Statut : </span>
              <Badge variant="outline">{meta.label}</Badge>
            </div>
            <div>
              <span className="text-muted-foreground">Clients : </span>
              {row.nb_clients}
            </div>
            <div>
              <span className="text-muted-foreground">Colis / Cartons : </span>
              {row.nb_colis} / {row.nb_cartons}
            </div>
            {row.mode_reglement && (
              <div>
                <span className="text-muted-foreground">Règlement : </span>
                {row.mode_reglement}
              </div>
            )}
            {row.validation_at && (
              <div>
                <span className="text-muted-foreground">Validé le : </span>
                {new Date(row.validation_at).toLocaleString("fr-FR")}
              </div>
            )}
          </div>
          <table className="w-full border-collapse text-xs">
            <thead>
              <tr className="bg-muted/40 text-left">
                <th className="border p-2">Catégorie</th>
                <th className="border p-2 text-right">Montant</th>
                <th className="border p-2 text-right">%</th>
              </tr>
            </thead>
            <tbody>
              {CATEGORIES.map((c) => {
                const v = Number(row[c.key] ?? 0);
                const pct = row.cout_total ? Math.round((v / Number(row.cout_total)) * 100) : 0;
                return (
                  <tr key={String(c.key)}>
                    <td className="border p-2">{c.label}</td>
                    <td className="border p-2 text-right tabular-nums">{fmtFCFA(v)}</td>
                    <td className="border p-2 text-right">{pct}%</td>
                  </tr>
                );
              })}
              <tr className="font-semibold bg-muted/20">
                <td className="border p-2">TOTAL</td>
                <td className="border p-2 text-right tabular-nums">{fmtFCFA(row.cout_total)}</td>
                <td className="border p-2 text-right">100%</td>
              </tr>
            </tbody>
          </table>
          {row.validation_commentaire && (
            <div className="rounded bg-muted/40 p-2 text-xs">
              <b>Commentaire :</b> {row.validation_commentaire}
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Fermer
          </Button>
          <Button onClick={openPdf}>
            <Printer className="mr-2 h-4 w-4" /> Aperçu / Imprimer
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function ValidateDialog({
  row,
  onClose,
  onDone,
}: {
  row: TourneeCout | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const [mode, setMode] = useState<"caisse" | "banque">("caisse");
  const [comment, setComment] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (row) {
      setMode("caisse");
      setComment("");
    }
  }, [row]);
  if (!row) return null;
  const submit = async () => {
    setBusy(true);
    const { error } = await supabase.rpc("valider_decaissement_tournee", {
      _tournee_id: row.tournee_id,
      _mode_reglement: mode,
      _commentaire: comment || undefined,
    });
    setBusy(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success("Décaissement validé — écriture comptable générée.");
    onDone();
    onClose();
  };
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Valider le décaissement — {row.reference}</DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div className="rounded bg-muted/40 p-3 text-sm">
            Montant à décaisser : <b>{fmtFCFA(row.cout_total)}</b>
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Mode de règlement</label>
            <Select value={mode} onValueChange={(v) => setMode(v as "caisse" | "banque")}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="caisse">Caisse (571)</SelectItem>
                <SelectItem value="banque">Banque (521)</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <label className="text-xs text-muted-foreground">Commentaire (facultatif)</label>
            <Textarea rows={3} value={comment} onChange={(e) => setComment(e.target.value)} />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Annuler
          </Button>
          <Button onClick={submit} disabled={busy}>
            {busy ? "Validation…" : "Valider le décaissement"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function RefuseDialog({
  row,
  onClose,
  onDone,
}: {
  row: TourneeCout | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const [comment, setComment] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (row) setComment("");
  }, [row]);
  if (!row) return null;
  const submit = async () => {
    if (!comment.trim()) {
      toast.error("Un motif est requis pour refuser.");
      return;
    }
    setBusy(true);
    const { error } = await supabase.rpc("refuser_tournee_couts", {
      _tournee_id: row.tournee_id,
      _commentaire: comment,
    });
    setBusy(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success("Coûts refusés.");
    onDone();
    onClose();
  };
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Refuser les coûts — {row.reference}</DialogTitle>
        </DialogHeader>
        <Textarea
          rows={4}
          placeholder="Motif du refus"
          value={comment}
          onChange={(e) => setComment(e.target.value)}
        />
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Annuler
          </Button>
          <Button variant="destructive" onClick={submit} disabled={busy}>
            {busy ? "…" : "Refuser"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
