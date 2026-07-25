import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { friendlyError } from "@/lib/friendly-error";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import {
  CheckCircle2,
  XCircle,
  Inbox,
  Loader2,
  FileCheck,
  AlertTriangle,
  Clock,
  ExternalLink,
  Search,
  History,
  Download,
} from "lucide-react";
import { toast } from "sonner";
import { formatDistanceToNow, formatDistanceToNowStrict, isPast, differenceInMinutes, format } from "date-fns";
import { fr } from "date-fns/locale";


import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";
import { formatFCFA } from "@/lib/format";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
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
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { FilterBadges, type FilterBadge } from "@/components/common/FilterBadges";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/approbations")({
  component: ApprobationsPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

type Statut = "en_attente" | "approuve" | "rejete";

const TYPE_LABEL: Record<string, string> = {
  achat: "Achat",
  depense: "Dépense",
  conge: "Congé",
  mission: "Mission",
  facture: "Facture",
  retour: "Retour",
  paiement: "Paiement",
  frais_logistique: "Frais logistique",
  annulation: "Annulation",
  autre: "Autre",
};

const MODULE_OPTIONS = [
  { value: "all", label: "Tous les modules" },
  { value: "retour", label: "Retours clients" },
  { value: "paiement", label: "Paiements" },
  { value: "frais_logistique", label: "Frais logistique" },
  { value: "annulation", label: "Annulations" },
  { value: "achat", label: "Achats / Dépenses" },
  { value: "rh", label: "RH (Congés, Missions)" },
  { value: "autre", label: "Autre" },
];

const URGENCE_META: Record<string, { label: string; color: string }> = {
  critique: { label: "Critique", color: "#DC2626" },
  urgent: { label: "Urgent", color: "#F97316" },
  normal: { label: "Normal", color: "#64748B" },
};

const STATUT_META: Record<Statut, { label: string; color: string }> = {
  en_attente: { label: "En attente", color: "#F97316" },
  approuve: { label: "Approuvée", color: "#10B981" },
  rejete: { label: "Rejetée", color: "#EF4444" },
};

type Approval = {
  id: string;
  workflow_code: string | null;
  entity_type: string | null;
  entity_id: string | null;
  module: string | null;
  niveau_urgence: string | null;
  sla_deadline: string | null;
  reference: string | null;
  demandeur_nom: string | null;
  statut: string;
  commentaire: string | null;
  motif_refus: string | null;
  metadata: Record<string, unknown> | null;
  simulation_financiere: Record<string, unknown> | null;
  created_at: string;
};

function getMetaString(meta: Record<string, unknown> | null, key: string): string | null {
  if (!meta) return null;
  const v = meta[key];
  return typeof v === "string" ? v : null;
}
function getMetaNumber(meta: Record<string, unknown> | null, key: string): number | null {
  if (!meta) return null;
  const v = meta[key];
  return typeof v === "number" ? v : null;
}

function deriveModule(row: Approval): string {
  if (row.module) return row.module;
  const key = row.entity_type ?? row.workflow_code ?? "";
  if (key === "retour") return "retour";
  if (key === "paiement") return "paiement";
  if (key === "frais_logistique" || key === "cout_logistique") return "frais_logistique";
  if (key === "annulation") return "annulation";
  if (key === "achat" || key === "depense") return "achat";
  if (key === "conge" || key === "mission") return "rh";
  return "autre";
}

function useApprovals(statut: Statut) {
  return useQuery({
    queryKey: ["approbations", "v2", statut],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("workflow_approvals")
        .select(
          "id, workflow_code, entity_type, entity_id, module, niveau_urgence, sla_deadline, reference, demandeur_nom, statut, commentaire, motif_refus, metadata, simulation_financiere, created_at",
        )
        .eq("statut", statut)
        .order("niveau_urgence", { ascending: true })
        .order("sla_deadline", { ascending: true, nullsFirst: false })
        .order("created_at", { ascending: false })
        .limit(300);
      if (error) throw error;
      return (data ?? []) as unknown as Approval[];
    },
    staleTime: 30_000,
  });
}

function ApprobationsPage() {
  const [tab, setTab] = useState<Statut>("en_attente");
  const [moduleFilter, setModuleFilter] = useState<string>("all");
  const [urgenceFilter, setUrgenceFilter] = useState<string>("all");
  const [search, setSearch] = useState("");

  const badges: FilterBadge[] = [];
  if (moduleFilter !== "all")
    badges.push({
      key: "module",
      label: `Module : ${MODULE_OPTIONS.find((m) => m.value === moduleFilter)?.label ?? moduleFilter}`,
      onClear: () => setModuleFilter("all"),
    });
  if (urgenceFilter !== "all")
    badges.push({
      key: "urg",
      label: `Urgence : ${URGENCE_META[urgenceFilter]?.label ?? urgenceFilter}`,
      onClear: () => setUrgenceFilter("all"),
    });
  if (search.trim())
    badges.push({ key: "q", label: `Recherche : « ${search} »`, onClear: () => setSearch("") });

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-semibold flex items-center gap-2">
            <FileCheck className="h-6 w-6" /> Centre d'approbations
          </h1>
          <p className="text-sm text-muted-foreground">
            Vue transversale — retours clients, paiements, frais logistique, annulations et
            demandes internes.
          </p>
        </div>
        <Button asChild variant="outline" size="sm">
          <Link to="/workflow-approvals">Gérer les demandes</Link>
        </Button>
      </div>

      <div className="flex flex-wrap gap-2 items-center">
        <div className="relative flex-1 min-w-[220px] max-w-md">
          <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Référence, demandeur, objet…"
            className="pl-8"
          />
        </div>
        <Select value={moduleFilter} onValueChange={setModuleFilter}>
          <SelectTrigger className="w-[200px]">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {MODULE_OPTIONS.map((m) => (
              <SelectItem key={m.value} value={m.value}>
                {m.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select value={urgenceFilter} onValueChange={setUrgenceFilter}>
          <SelectTrigger className="w-[160px]">
            <SelectValue placeholder="Urgence" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Toutes urgences</SelectItem>
            <SelectItem value="critique">Critique</SelectItem>
            <SelectItem value="urgent">Urgent</SelectItem>
            <SelectItem value="normal">Normal</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <FilterBadges badges={badges} onResetAll={() => {
        setModuleFilter("all"); setUrgenceFilter("all"); setSearch("");
      }} />

      <Tabs value={tab} onValueChange={(v) => setTab(v as Statut)}>
        <TabsList>
          <TabsTrigger value="en_attente">En attente</TabsTrigger>
          <TabsTrigger value="approuve">Approuvées</TabsTrigger>
          <TabsTrigger value="rejete">Rejetées</TabsTrigger>
        </TabsList>
        {(["en_attente", "approuve", "rejete"] as Statut[]).map((s) => (
          <TabsContent key={s} value={s} className="mt-4 space-y-4">
            <ApprovalsList
              statut={s}
              moduleFilter={moduleFilter}
              urgenceFilter={urgenceFilter}
              search={search}
            />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  );
}

function ApprovalsList({
  statut,
  moduleFilter,
  urgenceFilter,
  search,
}: {
  statut: Statut;
  moduleFilter: string;
  urgenceFilter: string;
  search: string;
}) {
  const { data = [], isLoading } = useApprovals(statut);
  const [dialog, setDialog] = useState<{ row: Approval; action: "approuve" | "rejete" } | null>(
    null,
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return data.filter((r) => {
      if (moduleFilter !== "all" && deriveModule(r) !== moduleFilter) return false;
      if (urgenceFilter !== "all" && (r.niveau_urgence ?? "normal") !== urgenceFilter) return false;
      if (q) {
        const hay = [
          r.reference,
          r.demandeur_nom,
          r.workflow_code,
          r.entity_type,
          getMetaString(r.metadata, "objet"),
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [data, moduleFilter, urgenceFilter, search]);

  const kpis = useMemo(() => {
    const total = filtered.length;
    const critiques = filtered.filter((r) => r.niveau_urgence === "critique").length;
    const slaDepasse = filtered.filter(
      (r) => r.sla_deadline && isPast(new Date(r.sla_deadline)),
    ).length;
    const montantTotal = filtered.reduce(
      (acc, r) => acc + (getMetaNumber(r.metadata, "montant") ?? 0),
      0,
    );
    return { total, critiques, slaDepasse, montantTotal };
  }, [filtered]);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-10 text-muted-foreground">
        <Loader2 className="h-5 w-5 animate-spin mr-2" /> Chargement…
      </div>
    );
  }

  return (
    <>
      {statut === "en_attente" && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <KpiCard label="À traiter" value={kpis.total.toString()} />
          <KpiCard
            label="Critiques"
            value={kpis.critiques.toString()}
            color={kpis.critiques > 0 ? "#DC2626" : undefined}
          />
          <KpiCard
            label="SLA dépassé"
            value={kpis.slaDepasse.toString()}
            color={kpis.slaDepasse > 0 ? "#F97316" : undefined}
          />
          <KpiCard label="Montant cumulé" value={formatFCFA(kpis.montantTotal)} />
        </div>
      )}

      {filtered.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center gap-2 py-12 text-muted-foreground">
            <Inbox className="h-8 w-8 opacity-40" />
            <p className="text-sm">Aucune demande dans cette catégorie.</p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-3">
          {filtered.map((row) => (
            <ApprovalCard
              key={row.id}
              row={row}
              onAction={(action) => setDialog({ row, action })}
            />
          ))}
        </div>
      )}

      {dialog && (
        <DecisionDialog row={dialog.row} action={dialog.action} onClose={() => setDialog(null)} />
      )}
    </>
  );
}

function KpiCard({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <Card>
      <CardContent className="p-3">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="text-xl font-semibold" style={color ? { color } : undefined}>
          {value}
        </p>
      </CardContent>
    </Card>
  );
}

function ApprovalCard({
  row,
  onAction,
}: {
  row: Approval;
  onAction: (action: "approuve" | "rejete") => void;
}) {
  const navigate = useNavigate();
  const meta = STATUT_META[row.statut as Statut] ?? STATUT_META.en_attente;
  const isPending = row.statut === "en_attente";
  const mod = deriveModule(row);
  const typeKey = row.entity_type ?? row.workflow_code ?? "autre";
  const objet = getMetaString(row.metadata, "objet");
  const montant = getMetaNumber(row.metadata, "montant");
  const urg = URGENCE_META[row.niveau_urgence ?? "normal"] ?? URGENCE_META.normal;
  const slaOver = row.sla_deadline ? isPast(new Date(row.sla_deadline)) : false;

  const openDetail = () => {
    if (mod === "retour" && row.entity_id) {
      navigate({ to: "/retours/$retourId", params: { retourId: row.entity_id } });
    }
  };

  const canOpenDetail = mod === "retour" && !!row.entity_id;

  return (
    <Card>
      <CardContent className="p-4">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <Badge variant="outline">{TYPE_LABEL[typeKey] ?? typeKey}</Badge>
              <span className="font-mono text-xs text-muted-foreground">
                {row.reference ?? row.id.slice(0, 8)}
              </span>
              <Badge style={{ background: meta.color, color: "white" }}>{meta.label}</Badge>
              {row.niveau_urgence && row.niveau_urgence !== "normal" && (
                <Badge style={{ background: urg.color, color: "white" }} className="gap-1">
                  <AlertTriangle className="h-3 w-3" /> {urg.label}
                </Badge>
              )}
              {row.sla_deadline && (
                <Badge
                  variant={slaOver ? "destructive" : "secondary"}
                  className="gap-1"
                  title={new Date(row.sla_deadline).toLocaleString("fr-FR")}
                >
                  <Clock className="h-3 w-3" />
                  {slaOver ? "SLA dépassé " : "SLA "}
                  {formatDistanceToNowStrict(new Date(row.sla_deadline), {
                    addSuffix: true,
                    locale: fr,
                  })}
                </Badge>
              )}
            </div>
            <p className="font-medium mt-2">{objet || "—"}</p>
            <div className="flex gap-4 text-xs text-muted-foreground mt-1 flex-wrap">
              <span>Demandeur : {row.demandeur_nom ?? "—"}</span>
              {montant != null && montant > 0 && (
                <span className="font-semibold text-foreground">{formatFCFA(montant)}</span>
              )}
              <span>
                {formatDistanceToNow(new Date(row.created_at), { addSuffix: true, locale: fr })}
              </span>
            </div>
            {row.motif_refus && (
              <p className="text-xs text-destructive mt-2 border-l-2 border-destructive pl-2 italic">
                Motif refus : {row.motif_refus}
              </p>
            )}
            {!row.motif_refus && row.commentaire && (
              <p className="text-xs text-muted-foreground mt-2 border-l-2 pl-2 italic whitespace-pre-line">
                {row.commentaire}
              </p>
            )}
          </div>
          <div className="flex gap-2 flex-wrap">
            {canOpenDetail && (
              <Button size="sm" variant="outline" onClick={openDetail}>
                <ExternalLink className="h-4 w-4 mr-1.5" /> Ouvrir la fiche
              </Button>
            )}
            {isPending && !canOpenDetail && (
              <>
                <Button size="sm" variant="outline" onClick={() => onAction("rejete")}>
                  <XCircle className="h-4 w-4 mr-1.5" /> Rejeter
                </Button>
                <Button size="sm" onClick={() => onAction("approuve")}>
                  <CheckCircle2 className="h-4 w-4 mr-1.5" /> Approuver
                </Button>
              </>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

function DecisionDialog({
  row,
  action,
  onClose,
}: {
  row: Approval;
  action: "approuve" | "rejete";
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const { user } = useAuth();
  const [comment, setComment] = useState("");
  const [busy, setBusy] = useState(false);

  const isApprove = action === "approuve";
  const meta = STATUT_META[action];
  const actorName =
    (user?.user_metadata?.nom_complet as string | undefined) || user?.email || "Système";
  const typeKey = row.entity_type ?? row.workflow_code ?? "autre";
  const objet = getMetaString(row.metadata, "objet");
  const montant = getMetaNumber(row.metadata, "montant");

  const submit = async () => {
    try {
      setBusy(true);
      const decisionNote = `[${isApprove ? "Approuvée" : "Rejetée"} par ${actorName}${
        comment ? ` — ${comment}` : ""
      }]`;

      const { error } = await supabase.rpc("approbation_decider", {
        p_approbation_id: row.id,
        p_decision: isApprove ? "approuve" : "rejete",
        p_commentaire: comment || decisionNote,
      });
      if (error) throw error;

      toast.success(
        `Demande ${isApprove ? "approuvée" : "rejetée"} — impact appliqué au module ${row.module ?? typeKey}`,
      );
      qc.invalidateQueries({ queryKey: ["approbations"] });
      qc.invalidateQueries({ queryKey: ["paiements"] });
      qc.invalidateQueries({ queryKey: ["commandes"] });
      qc.invalidateQueries({ queryKey: ["couts_logistiques"] });
      onClose();
    } catch (e) {
      toast.error(friendlyError(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {isApprove ? "Approuver" : "Rejeter"} la demande {row.reference ?? row.id.slice(0, 8)}
          </DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div className="rounded-md border p-3 text-sm space-y-1">
            <p>
              <span className="text-muted-foreground">Type :</span>{" "}
              {TYPE_LABEL[typeKey] ?? typeKey}
            </p>
            <p>
              <span className="text-muted-foreground">Demandeur :</span> {row.demandeur_nom ?? "—"}
            </p>
            <p>
              <span className="text-muted-foreground">Objet :</span> {objet || "—"}
            </p>
            {montant != null && montant > 0 && (
              <p>
                <span className="text-muted-foreground">Montant :</span> {formatFCFA(montant)}
              </p>
            )}
          </div>
          <div>
            <label className="text-xs font-medium mb-1 block">
              Commentaire {isApprove ? "(optionnel)" : "(recommandé)"}
            </label>
            <Textarea
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder={isApprove ? "Motif d'approbation…" : "Motif de rejet…"}
              rows={3}
            />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Annuler
          </Button>
          <Button
            onClick={submit}
            disabled={busy}
            style={{ background: meta.color, color: "white" }}
          >
            {busy && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
            Confirmer {isApprove ? "l'approbation" : "le rejet"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
