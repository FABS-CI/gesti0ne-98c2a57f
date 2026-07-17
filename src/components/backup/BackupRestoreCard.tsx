import { getCurrentUser } from "@/lib/current-user";
import { useState } from "react";
import {
  Loader2,
  Upload,
  RotateCcw,
  ShieldAlert,
  AlertTriangle,
  ShieldCheck,
  FileText,
} from "lucide-react";
import { toast } from "sonner";

import { supabase } from "@/integrations/supabase/client";
import { exportCsv } from "@/lib/export-csv";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

// Mapping table -> colonne clé primaire (cible d'onConflict pour upsert)
const PK_MAP: Record<string, string> = {
  // Administration & RBAC
  profiles: "id",
  rbac_roles: "id",
  rbac_permissions: "code",
  rbac_role_permissions: "role_id,permission_code",
  user_roles: "id",
  rbac_user_roles: "id",
  parametres_systeme: "parametre_id",
  parametres_entreprise: "parametre_id",
  // Référentiels
  departements: "departement_id",
  fonctions: "fonction_id",
  depots: "depot_id",
  preparateurs: "preparateur_id",
  livreurs: "livreur_id",
  vehicules: "vehicule_id",
  plan_comptable: "compte_id",
  journaux_comptables: "journal_id",
  exercices_comptables: "exercice_id",
  rubriques_paie: "rubrique_id",
  parametres_paie: "parametre_id",
  // Tiers & catalogue
  clients: "client_id",
  fournisseurs: "fournisseur_id",
  produits: "produit_id",
  employes: "employe_id",
  // Commercial
  proformas: "proforma_id",
  proforma_lignes: "ligne_id",
  commandes: "commande_id",
  commande_lignes: "ligne_id",
  factures: "facture_id",
  paiements: "paiement_id",
  paiement_annulations_audit: "id",
  retours: "retour_id",
  retour_lignes: "ligne_id",
  specimens: "specimen_id",
  crm_interactions: "interaction_id",
  // Achats & stock
  achats: "achat_id",
  achat_lignes: "ligne_id",
  approvisionnements: "approvisionnement_id",
  approvisionnement_lignes: "ligne_id",
  stock_mouvements: "mouvement_id",
  inventaires: "inventaire_id",
  inventaire_lignes: "ligne_id",
  transferts: "transfert_id",
  transfert_lignes: "ligne_id",
  incidents: "incident_id",
  alertes_stock: "alerte_id",
  audit_stock: "audit_id",
  // Logistique
  tournees: "tournee_id",

  livraisons: "livraison_id",
  bons_livraison: "bon_id",
  // Finance & compta
  transactions: "transaction_id",
  fne_declarations: "fne_id",
  couts_logistiques: "cout_id",
  ecritures_comptables: "ecriture_id",
  ecriture_lignes: "ligne_id",
  // RH & paie
  contrats: "contrat_id",
  conges: "conge_id",
  absences: "absence_id",
  missions: "mission_id",
  evaluations: "evaluation_id",
  bulletins_paie: "bulletin_id",
  bulletin_lignes: "ligne_id",
  declarations_paie: "declaration_id",
  // Journaux
  audit_logs: "id",
  rbac_audit_log: "id",
};

// Ordre de restauration respectant les dépendances FK (parents avant enfants)
const RESTORE_ORDER = [
  "profiles",
  "rbac_roles",
  "rbac_permissions",
  "rbac_role_permissions",
  "user_roles",
  "rbac_user_roles",
  "parametres_systeme",
  "parametres_entreprise",
  "departements",
  "fonctions",
  "depots",
  "preparateurs",
  "livreurs",
  "vehicules",
  "plan_comptable",
  "journaux_comptables",
  "exercices_comptables",
  "rubriques_paie",
  "parametres_paie",
  "clients",
  "fournisseurs",
  "produits",
  "employes",
  "contrats",
  "proformas",
  "proforma_lignes",
  "commandes",
  "commande_lignes",
  "factures",
  "paiements",
  "paiement_annulations_audit",
  "retours",
  "retour_lignes",
  "specimens",
  "crm_interactions",
  "achats",
  "achat_lignes",
  "approvisionnements",
  "approvisionnement_lignes",
  "stock_mouvements",
  "inventaires",
  "inventaire_lignes",
  "transferts",
  "transfert_lignes",
  "incidents",
  "alertes_stock",
  "audit_stock",
  "tournees",
  "livraisons",

  "bons_livraison",
  "transactions",
  "fne_declarations",
  "couts_logistiques",
  "ecritures_comptables",
  "ecriture_lignes",
  "conges",
  "absences",
  "missions",
  "evaluations",
  "bulletins_paie",
  "bulletin_lignes",
  "declarations_paie",
  "audit_logs",
  "rbac_audit_log",
];

type Analysis = {
  table: string;
  rowsInFile: number;
  rowsInDb: number | null;
  pk: string | null;
  error?: string;
};

type BackupFile = Record<string, Record<string, unknown>[]>;

type RestoreReport = {
  fileName: string;
  sha256: string | null;
  shaMatch: "match" | "unknown" | null;
  startedAt: string;
  duree_ms: number;
  lignes: Array<{
    table: string;
    pk: string | null;
    rowsInFile: number;
    rowsInDbBefore: number | null;
    inserted: number;
    error?: string;
  }>;
};

export function BackupRestoreCard() {
  const [file, setFile] = useState<BackupFile | null>(null);
  const [fileName, setFileName] = useState<string>("");
  const [fileSha, setFileSha] = useState<string | null>(null);
  const [shaMatch, setShaMatch] = useState<"match" | "unknown" | null>(null);
  const [analysis, setAnalysis] = useState<Analysis[] | null>(null);
  const [selected, setSelected] = useState<Record<string, boolean>>({});
  const [confirm, setConfirm] = useState("");
  const [analyzing, setAnalyzing] = useState(false);
  const [running, setRunning] = useState(false);
  const [progress, setProgress] = useState("");
  const [lastReport, setLastReport] = useState<RestoreReport | null>(null);

  async function onUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    try {
      const text = await f.text();
      const json = JSON.parse(text);
      if (typeof json !== "object" || json === null || Array.isArray(json)) {
        throw new Error("Format invalide: le JSON doit être un objet { table: [...] }");
      }
      // Vérification d'intégrité : SHA-256 du fichier vs backups.sha256
      const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
      const sha = Array.from(new Uint8Array(buf))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
      setFileSha(sha);
      const { data: match } = await supabase
        .from("backups")
        .select("backup_id")
        .eq("sha256", sha)
        .limit(1);
      setShaMatch(match && match.length > 0 ? "match" : "unknown");
      setFile(json as BackupFile);
      setFileName(f.name);
      setAnalysis(null);
      setSelected({});
      setConfirm("");
      setLastReport(null);
      toast.success(`Fichier chargé: ${f.name}`);
    } catch (err) {
      toast.error(`Fichier invalide: ${(err as Error).message}`);
    }
  }

  async function runAnalysis() {
    if (!file) return;
    setAnalyzing(true);
    const results: Analysis[] = [];
    for (const table of Object.keys(file)) {
      const rows = file[table] ?? [];
      const pk = PK_MAP[table] ?? null;
      let rowsInDb: number | null = null;
      let error: string | undefined;
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const { count, error: e } = await (supabase.from(table as any) as any).select("*", {
          count: "exact",
          head: true,
        });
        if (e) error = e.message;
        else rowsInDb = count ?? 0;
      } catch (e) {
        error = (e as Error).message;
      }
      results.push({ table, rowsInFile: rows.length, rowsInDb, pk, error });
    }
    setAnalysis(results);
    // Sélection par défaut: tables avec PK connu et données
    const sel: Record<string, boolean> = {};
    for (const r of results) sel[r.table] = !!(r.pk && r.rowsInFile > 0 && !r.error);
    setSelected(sel);
    setAnalyzing(false);
  }

  async function logAudit(action: string, details: Record<string, unknown>) {
    const { data: userData } = await getCurrentUser();
    await supabase.from("audit_logs").insert({
      user_id: userData.user?.id ?? null,
      user_email: userData.user?.email ?? null,
      action,
      table_name: "backups",
      new_values: details as never,
    });
  }

  async function runRestore() {
    if (!file || !analysis) return;
    if (confirm !== "RESTAURER") {
      toast.error('Tapez exactement "RESTAURER" pour confirmer');
      return;
    }
    const tables = analysis
      .filter((a) => selected[a.table] && a.pk && a.rowsInFile > 0)
      .slice()
      .sort((a, b) => {
        const ia = RESTORE_ORDER.indexOf(a.table);
        const ib = RESTORE_ORDER.indexOf(b.table);
        return (ia === -1 ? 999 : ia) - (ib === -1 ? 999 : ib);
      });
    if (!tables.length) {
      toast.error("Aucune table sélectionnée avec clé primaire connue");
      return;
    }
    setRunning(true);
    const t0 = Date.now();
    const startedAt = new Date().toISOString();
    const report: Record<string, { inserted: number; error?: string }> = {};
    try {
      for (const a of tables) {
        setProgress(`Restauration de ${a.table} (${a.rowsInFile} lignes)…`);
        try {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const { error } = await (supabase.from(a.table as any) as any).upsert(file[a.table], {
            onConflict: a.pk as string,
          });
          if (error) report[a.table] = { inserted: 0, error: error.message };
          else report[a.table] = { inserted: a.rowsInFile };
        } catch (e) {
          report[a.table] = { inserted: 0, error: (e as Error).message };
        }
      }
      const okCount = Object.values(report).filter((r) => !r.error).length;
      const koCount = Object.values(report).filter((r) => !!r.error).length;
      const duree_ms = Date.now() - t0;
      const lignes: RestoreReport["lignes"] = tables.map((a) => ({
        table: a.table,
        pk: a.pk,
        rowsInFile: a.rowsInFile,
        rowsInDbBefore: a.rowsInDb,
        inserted: report[a.table]?.inserted ?? 0,
        error: report[a.table]?.error,
      }));
      setLastReport({
        fileName,
        sha256: fileSha,
        shaMatch,
        startedAt,
        duree_ms,
        lignes,
      });
      await logAudit("backup_restore", {
        fichier: fileName,
        duree_ms,
        sha256: fileSha,
        sha_match: shaMatch,
        tables_ok: okCount,
        tables_ko: koCount,
        detail: report,
      });
      if (koCount === 0) toast.success(`Restauration terminée: ${okCount} table(s)`);
      else toast.error(`Restauration partielle: ${okCount} OK, ${koCount} en échec`);
    } finally {
      setRunning(false);
      setProgress("");
      setConfirm("");
    }
  }

  function downloadReport() {
    if (!lastReport) return;
    const r = lastReport;
    const headers = [
      "Table",
      "Clé primaire",
      "Lignes fichier",
      "Lignes avant",
      "Restaurées",
      "Écart (après - avant)",
      "Statut",
    ];
    const rows = r.lignes.map((l) => {
      const after = (l.rowsInDbBefore ?? 0) + l.inserted; // borne haute (upsert : peut être ≤)
      const ecart = l.rowsInDbBefore == null ? "—" : String(after - (l.rowsInDbBefore ?? 0));
      return [
        l.table,
        l.pk ?? "—",
        String(l.rowsInFile),
        l.rowsInDbBefore == null ? "—" : String(l.rowsInDbBefore),
        String(l.inserted),
        ecart,
        l.error ? `ÉCHEC — ${l.error}` : "OK",
      ];
    });
    const totalFile = r.lignes.reduce((s, l) => s + l.rowsInFile, 0);
    const totalIns = r.lignes.reduce((s, l) => s + l.inserted, 0);
    const totalKo = r.lignes.filter((l) => l.error).length;
    exportCsv(
      `rapport_restauration_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-")}`,
      headers,
      rows,
      {
        pageTitle: "RAPPORT DE RESTAURATION",
        summary: [
          { label: "Fichier source", value: r.fileName },
          { label: "SHA-256 (fichier)", value: r.sha256 ?? "—" },
          {
            label: "Vérification d'intégrité",
            value:
              r.shaMatch === "match"
                ? "OK — hash trouvé dans l'historique"
                : "Hash absent de l'historique",
          },
          { label: "Démarrée le", value: new Date(r.startedAt).toLocaleString("fr-FR") },
          { label: "Durée", value: `${(r.duree_ms / 1000).toFixed(1)} s` },
          { label: "Tables traitées", value: String(r.lignes.length) },
          { label: "Tables en échec", value: String(totalKo) },
          { label: "Total lignes fichier", value: String(totalFile) },
          { label: "Total lignes restaurées", value: String(totalIns) },
        ],
      },
    );
  }

  const canRestore = !!analysis && confirm === "RESTAURER" && !running;
  const selectedCount = analysis?.filter((a) => selected[a.table]).length ?? 0;

  return (
    <Card className="border-amber-500/40">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <RotateCcw className="h-5 w-5 text-amber-600" /> Restauration d'une sauvegarde
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-start gap-2 rounded-md border border-amber-500/40 bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-950/30 dark:text-amber-200">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <div>
            <b>Opération sensible.</b> La restauration met à jour (upsert) les enregistrements
            existants et insère les manquants dans les tables sélectionnées. Aucune donnée n'est
            supprimée. Un rapport est enregistré dans le journal d'audit.
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <label className="inline-flex cursor-pointer items-center gap-2 rounded-md border bg-background px-3 py-2 text-sm hover:bg-accent">
            <Upload className="h-4 w-4" />
            <span>Choisir un fichier JSON</span>
            <input type="file" accept="application/json" className="hidden" onChange={onUpload} />
          </label>
          {fileName && <Badge variant="secondary">{fileName}</Badge>}
          {fileSha &&
            (shaMatch === "match" ? (
              <Badge className="bg-sky-600 hover:bg-sky-700" title={fileSha}>
                <ShieldCheck className="mr-1 h-3 w-3" /> Intégrité vérifiée
              </Badge>
            ) : (
              <Badge variant="outline" title={fileSha}>
                <ShieldAlert className="mr-1 h-3 w-3" /> Hash inconnu
              </Badge>
            ))}
          <Button variant="outline" onClick={runAnalysis} disabled={!file || analyzing}>
            {analyzing ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
            Analyser (dry-run)
          </Button>
        </div>

        {analysis && (
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-8"></TableHead>
                  <TableHead>Table</TableHead>
                  <TableHead>Clé primaire</TableHead>
                  <TableHead className="text-right">Lignes fichier</TableHead>
                  <TableHead className="text-right">Lignes actuelles</TableHead>
                  <TableHead>Statut</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {analysis.map((a) => {
                  const disabled = !a.pk || a.rowsInFile === 0 || !!a.error;
                  return (
                    <TableRow key={a.table}>
                      <TableCell>
                        <Checkbox
                          checked={!!selected[a.table]}
                          disabled={disabled}
                          onCheckedChange={(v) =>
                            setSelected((s) => ({ ...s, [a.table]: v === true }))
                          }
                        />
                      </TableCell>
                      <TableCell className="font-medium">{a.table}</TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {a.pk ?? <span className="text-destructive">inconnue</span>}
                      </TableCell>
                      <TableCell className="text-right">{a.rowsInFile}</TableCell>
                      <TableCell className="text-right">{a.rowsInDb ?? "—"}</TableCell>
                      <TableCell>
                        {a.error ? (
                          <Badge variant="destructive">{a.error}</Badge>
                        ) : !a.pk ? (
                          <Badge variant="outline">
                            <ShieldAlert className="mr-1 h-3 w-3" /> non restaurable
                          </Badge>
                        ) : a.rowsInFile === 0 ? (
                          <Badge variant="outline">vide</Badge>
                        ) : (
                          <Badge variant="secondary">prêt</Badge>
                        )}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        )}

        {analysis && (
          <div className="space-y-3 rounded-md border border-destructive/40 bg-destructive/5 p-3">
            <div className="text-sm">
              <b>{selectedCount}</b> table(s) sélectionnée(s). Pour confirmer, tapez{" "}
              <code className="rounded bg-background px-1">RESTAURER</code> ci-dessous.
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Input
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                placeholder="RESTAURER"
                className="max-w-xs"
              />
              <Button
                variant="destructive"
                onClick={runRestore}
                disabled={!canRestore || selectedCount === 0}
              >
                {running ? (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                ) : (
                  <RotateCcw className="mr-2 h-4 w-4" />
                )}
                {running ? progress || "Restauration…" : "Lancer la restauration"}
              </Button>
            </div>
          </div>
        )}

        {lastReport && (
          <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border bg-muted/40 p-3 text-sm">
            <div>
              Dernier rapport&nbsp;: <b>{lastReport.lignes.length}</b> table(s),{" "}
              {lastReport.lignes.filter((l) => l.error).length} en échec — durée{" "}
              {(lastReport.duree_ms / 1000).toFixed(1)} s.
            </div>
            <Button variant="outline" size="sm" onClick={downloadReport}>
              <FileText className="mr-2 h-4 w-4" /> Télécharger le rapport PDF
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
