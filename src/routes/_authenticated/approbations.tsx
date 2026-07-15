import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { CheckCircle2, XCircle, Inbox, Loader2, FileCheck } from "lucide-react";
import { toast } from "sonner";
import { formatDistanceToNow } from "date-fns";
import { fr } from "date-fns/locale";

import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";
import { formatFCFA } from "@/lib/format";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";

export const Route = createFileRoute("/_authenticated/approbations")({
  component: ApprobationsPage,
});

type Statut = "en_attente" | "approuve" | "rejete";

const TYPE_LABEL: Record<string, string> = {
  achat: "Achat",
  depense: "Dépense",
  conge: "Congé",
  mission: "Mission",
  facture: "Facture",
  autre: "Autre",
};

const STATUT_META: Record<Statut, { label: string; color: string }> = {
  en_attente: { label: "En attente", color: "#F97316" },
  approuve: { label: "Approuvée", color: "#10B981" },
  rejete: { label: "Rejetée", color: "#EF4444" },
};

type Approval = {
  approval_id: string;
  reference: string;
  type_demande: string;
  demandeur: string;
  objet: string | null;
  montant: number | null;
  date_demande: string;
  statut: string;
  notes: string | null;
  created_at: string;
};

function useApprovals(statut: Statut) {
  return useQuery({
    queryKey: ["approbations", statut],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("workflow_approvals")
        .select("*")
        .eq("statut", statut)
        .order("created_at", { ascending: false })
        .limit(200);
      if (error) throw error;
      return (data ?? []) as Approval[];
    },
  });
}

function ApprobationsPage() {
  const [tab, setTab] = useState<Statut>("en_attente");

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-semibold flex items-center gap-2">
            <FileCheck className="h-6 w-6" /> Approbations
          </h1>
          <p className="text-sm text-muted-foreground">
            Validez ou rejetez les demandes en attente. Chaque décision génère une notification.
          </p>
        </div>
        <Button asChild variant="outline" size="sm">
          <Link to="/workflow-approvals">Gérer les demandes</Link>
        </Button>
      </div>

      <Tabs value={tab} onValueChange={(v) => setTab(v as Statut)}>
        <TabsList>
          <TabsTrigger value="en_attente">En attente</TabsTrigger>
          <TabsTrigger value="approuve">Approuvées</TabsTrigger>
          <TabsTrigger value="rejete">Rejetées</TabsTrigger>
        </TabsList>
        {(["en_attente", "approuve", "rejete"] as Statut[]).map((s) => (
          <TabsContent key={s} value={s} className="mt-4">
            <ApprovalsList statut={s} />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  );
}

function ApprovalsList({ statut }: { statut: Statut }) {
  const { data = [], isLoading } = useApprovals(statut);
  const [dialog, setDialog] = useState<{ row: Approval; action: "approuve" | "rejete" } | null>(
    null,
  );

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-10 text-muted-foreground">
        <Loader2 className="h-5 w-5 animate-spin mr-2" /> Chargement…
      </div>
    );
  }
  if (data.length === 0) {
    return (
      <Card>
        <CardContent className="flex flex-col items-center gap-2 py-12 text-muted-foreground">
          <Inbox className="h-8 w-8 opacity-40" />
          <p className="text-sm">Aucune demande dans cette catégorie.</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <>
      <div className="grid gap-3">
        {data.map((row) => (
          <ApprovalCard
            key={row.approval_id}
            row={row}
            onAction={(action) => setDialog({ row, action })}
          />
        ))}
      </div>

      {dialog && (
        <DecisionDialog row={dialog.row} action={dialog.action} onClose={() => setDialog(null)} />
      )}
    </>
  );
}

function ApprovalCard({
  row,
  onAction,
}: {
  row: Approval;
  onAction: (action: "approuve" | "rejete") => void;
}) {
  const meta = STATUT_META[row.statut as Statut] ?? STATUT_META.en_attente;
  const isPending = row.statut === "en_attente";

  return (
    <Card>
      <CardContent className="p-4">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <Badge variant="outline">{TYPE_LABEL[row.type_demande] ?? row.type_demande}</Badge>
              <span className="font-mono text-xs text-muted-foreground">{row.reference}</span>
              <Badge style={{ background: meta.color, color: "white" }}>{meta.label}</Badge>
            </div>
            <p className="font-medium mt-2">{row.objet || "—"}</p>
            <div className="flex gap-4 text-xs text-muted-foreground mt-1 flex-wrap">
              <span>Demandeur : {row.demandeur}</span>
              {row.montant != null && row.montant > 0 && (
                <span className="font-semibold text-foreground">{formatFCFA(row.montant)}</span>
              )}
              <span>
                {formatDistanceToNow(new Date(row.created_at), { addSuffix: true, locale: fr })}
              </span>
            </div>
            {row.notes && (
              <p className="text-xs text-muted-foreground mt-2 border-l-2 pl-2 italic">
                {row.notes}
              </p>
            )}
          </div>
          {isPending && (
            <div className="flex gap-2">
              <Button size="sm" variant="outline" onClick={() => onAction("rejete")}>
                <XCircle className="h-4 w-4 mr-1.5" /> Rejeter
              </Button>
              <Button size="sm" onClick={() => onAction("approuve")}>
                <CheckCircle2 className="h-4 w-4 mr-1.5" /> Approuver
              </Button>
            </div>
          )}
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

  const submit = async () => {
    try {
      setBusy(true);
      const decisionNote = `[${isApprove ? "Approuvée" : "Rejetée"} par ${actorName}${
        comment ? ` — ${comment}` : ""
      }]`;
      const newNotes = [row.notes, decisionNote].filter(Boolean).join("\n");

      const { error } = await supabase
        .from("workflow_approvals")
        .update({ statut: action, notes: newNotes })
        .eq("approval_id", row.approval_id);
      if (error) throw error;

      await supabase.from("notifications").insert({
        titre: `Demande ${row.reference} ${isApprove ? "approuvée" : "rejetée"}`,
        message: `${TYPE_LABEL[row.type_demande] ?? row.type_demande} de ${row.demandeur}${
          comment ? ` — ${comment}` : ""
        }`,
        type_notification: isApprove ? "succes" : "alerte",
        lu: false,
        date_notification: new Date().toISOString().slice(0, 10),
      });

      toast.success(`Demande ${isApprove ? "approuvée" : "rejetée"}`);
      qc.invalidateQueries({ queryKey: ["approbations"] });
      onClose();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {isApprove ? "Approuver" : "Rejeter"} la demande {row.reference}
          </DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div className="rounded-md border p-3 text-sm space-y-1">
            <p>
              <span className="text-muted-foreground">Type :</span>{" "}
              {TYPE_LABEL[row.type_demande] ?? row.type_demande}
            </p>
            <p>
              <span className="text-muted-foreground">Demandeur :</span> {row.demandeur}
            </p>
            <p>
              <span className="text-muted-foreground">Objet :</span> {row.objet || "—"}
            </p>
            {row.montant != null && row.montant > 0 && (
              <p>
                <span className="text-muted-foreground">Montant :</span> {formatFCFA(row.montant)}
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
