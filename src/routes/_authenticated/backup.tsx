import { getCurrentUser } from "@/lib/current-user";
import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import {
  DatabaseBackup,
  Download,
  Loader2,
  ShieldAlert,
  HardDrive,
  Clock,
  CheckCircle2,
  XCircle,
  History,
  User as UserIcon,
  ShieldCheck,
  Cloud,
} from "lucide-react";

import { supabase } from "@/integrations/supabase/client";
import { exportCsv } from "@/lib/export-csv";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { BackupSchedulesCard } from "@/components/backup/BackupSchedulesCard";
import { BackupRestoreCard } from "@/components/backup/BackupRestoreCard";
import { useServerFn } from "@tanstack/react-start";
import { uploadBackupToGoogleDrive } from "@/lib/gdrive-backup.functions";
import { exportCriticalArtifacts } from "@/lib/gdrive-artifacts-backup.functions";
import { exportStorageBinariesZip } from "@/lib/gdrive-covers-zip.functions";
import { Checkbox } from "@/components/ui/checkbox";
import { Link } from "@tanstack/react-router";

export const Route = createFileRoute("/_authenticated/backup")({
  component: BackupPage,
});

const TABLES = [
  // Administration & RBAC
  "profiles",
  "rbac_roles",
  "rbac_permissions",
  "rbac_role_permissions",
  "user_roles",
  "rbac_user_roles",
  "parametres_systeme",
  "parametres_entreprise",
  // Référentiels
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
  // Tiers & catalogue
  "clients",
  "fournisseurs",
  "produits",
  "employes",
  // Commercial
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
  // Achats & stock
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
  // Logistique
  "tournees",

  "livraisons",
  "bons_livraison",
  // Finance & compta
  "transactions",
  "fne_declarations",
  "couts_logistiques",
  "ecritures_comptables",
  "ecriture_lignes",
  // RH & paie
  "contrats",
  "conges",
  "absences",
  "missions",
  "evaluations",
  "bulletins_paie",
  "bulletin_lignes",
  "declarations_paie",
  // Journaux
  "audit_logs",
  "rbac_audit_log",
];


type BackupRow = {
  backup_id: string;
  created_at: string;
  started_at: string;
  finished_at: string | null;
  user_email: string | null;
  type: string;
  destination: string;
  statut: "en_cours" | "succes" | "echec";
  taille_octets: number | null;
  duree_ms: number | null;
  nb_tables: number | null;
  nb_enregistrements: number | null;
  fichier_nom: string | null;
  message: string | null;
  sha256: string | null;
  verifie: boolean | null;
  destination_url: string | null;
};

function formatSize(n: number | null) {
  if (!n) return "—";
  if (n < 1024) return `${n} o`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} Ko`;
  return `${(n / (1024 * 1024)).toFixed(2)} Mo`;
}
function formatDuration(ms: number | null) {
  if (!ms) return "—";
  if (ms < 1000) return `${ms} ms`;
  return `${(ms / 1000).toFixed(1)} s`;
}

function BackupPage() {
  const [running, setRunning] = useState(false);
  const [progress, setProgress] = useState<string>("");
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [history, setHistory] = useState<BackupRow[]>([]);
  const [loadingHistory, setLoadingHistory] = useState(false);
  const [sendToDrive, setSendToDrive] = useState(true);
  const uploadToDrive = useServerFn(uploadBackupToGoogleDrive);
  const runCriticalExport = useServerFn(exportCriticalArtifacts);
  const [criticalRunning, setCriticalRunning] = useState(false);
  const [criticalResult, setCriticalResult] = useState<{
    users_count: number;
    buckets_count: number;
    files_count: number;
    users_drive: { id: string; url: string | null };
    storage_drive: { id: string; url: string | null };
  } | null>(null);
  const runBinariesZip = useServerFn(exportStorageBinariesZip);
  const [binariesRunning, setBinariesRunning] = useState(false);
  const [binariesResult, setBinariesResult] = useState<{
    total_files: number;
    total_bytes: number;
    zip_bytes: number;
    buckets: Array<{ bucket: string; files: number; bytes: number }>;
    drive: { id: string; url: string | null };
  } | null>(null);

  async function backupCriticalArtifacts() {
    setCriticalRunning(true);
    try {
      const res = await runCriticalExport();
      setCriticalResult(res);
      toast.success(
        `Export critique OK — ${res.users_count} comptes, ${res.files_count} fichiers`,
      );
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setCriticalRunning(false);
    }
  }

  async function backupBinariesZip() {
    setBinariesRunning(true);
    try {
      const res = await runBinariesZip();
      setBinariesResult(res);
      toast.success(
        `ZIP binaires OK — ${res.total_files} fichiers (${(res.zip_bytes / 1024 / 1024).toFixed(1)} Mo)`,
      );
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBinariesRunning(false);
    }
  }

  useEffect(() => {
    (async () => {
      const { data: userData } = await getCurrentUser();
      setUserEmail(userData.user?.email ?? null);
      if (!userData.user) {
        setIsAdmin(false);
        return;
      }
      const { data, error } = await supabase.rpc("has_role", {
        _user_id: userData.user.id,
        _role: "super_admin",
      });
      setIsAdmin(!error && data === true);
    })();
  }, []);

  async function loadHistory() {
    setLoadingHistory(true);
    const { data, error } = await supabase
      .from("backups")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(50);
    setLoadingHistory(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    setHistory((data ?? []) as BackupRow[]);
  }
  useEffect(() => {
    if (isAdmin) loadHistory();
  }, [isAdmin]);

  async function logAudit(
    action: string,
    backupId: string,
    details: Record<string, string | number | boolean | null>,
  ) {
    const { data: userData } = await getCurrentUser();
    await supabase.from("audit_logs").insert({
      user_id: userData.user?.id ?? null,
      user_email: userData.user?.email ?? null,
      action,
      table_name: "backups",
      record_id: backupId,
      new_values: details,
    });
  }

  async function fetchTable(table: string) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { data, error } = await (supabase.from(table as any) as any).select("*");
    if (error) throw error;
    return (data ?? []) as Record<string, unknown>[];
  }

  async function backupAllJson() {
    if (!isAdmin) {
      toast.error("Accès refusé");
      return;
    }
    try {
      const { assertPermission } = await import("@/lib/rbac-api");
      await assertPermission("backup.planifier");
    } catch (e) {
      toast.error((e as Error).message);
      return;
    }
    setRunning(true);
    const t0 = Date.now();
    // Créer l'entrée d'historique
    const { data: created, error: insErr } = await supabase
      .from("backups")
      .insert({
        type: "complete",
        destination: "local",
        statut: "en_cours",
        user_email: userEmail,
        scope: { tables: TABLES },
      })
      .select("backup_id")
      .single();
    if (insErr || !created) {
      setRunning(false);
      toast.error(insErr?.message ?? "Impossible de démarrer la sauvegarde");
      return;
    }
    const backupId = created.backup_id as string;
    try {
      const backup: Record<string, unknown[]> = {};
      let totalRows = 0;
      for (const t of TABLES) {
        setProgress(`Sauvegarde de ${t}...`);
        backup[t] = await fetchTable(t);
        totalRows += backup[t].length;
      }
      const json = JSON.stringify(backup, null, 2);
      const blob = new Blob([json], { type: "application/json" });
      // SHA-256 (Web Crypto) pour vérification d'intégrité
      const hashBuf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(json));
      const sha256 = Array.from(new Uint8Array(hashBuf))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
      const fichier_nom = `backup_fabs_${new Date().toISOString().slice(0, 10)}.json`;
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = fichier_nom;
      a.click();
      URL.revokeObjectURL(url);
      const duree_ms = Date.now() - t0;
      await supabase
        .from("backups")
        .update({
          statut: "succes",
          finished_at: new Date().toISOString(),
          taille_octets: blob.size,
          duree_ms,
          nb_tables: TABLES.length,
          nb_enregistrements: totalRows,
          fichier_nom,
          sha256,
          verifie: true,
          verifie_at: new Date().toISOString(),
          verifie_methode: "sha256-auto",
        })
        .eq("backup_id", backupId);
      await logAudit("backup_create", backupId, {
        type: "complete",
        nb_tables: TABLES.length,
        nb_enregistrements: totalRows,
        taille_octets: blob.size,
        duree_ms,
        sha256,
      });
      toast.success("Sauvegarde JSON générée");
      if (sendToDrive) {
        setProgress("Envoi vers Google Drive…");
        try {
          const res = await uploadToDrive({
            data: { backupId, fileName: fichier_nom, json, sha256 },
          });
          await logAudit("backup_upload_gdrive", backupId, {
            file_id: res.id,
            url: res.url,
          });
          toast.success("Envoyée vers Google Drive");
        } catch (e) {
          toast.error(`Google Drive: ${(e as Error).message}`);
        }
      }
      loadHistory();
    } catch (e) {
      await supabase
        .from("backups")
        .update({
          statut: "echec",
          finished_at: new Date().toISOString(),
          duree_ms: Date.now() - t0,
          error: (e as Error).message,
        })
        .eq("backup_id", backupId);
      await logAudit("backup_failed", backupId, { error: (e as Error).message });
      toast.error((e as Error).message);
      loadHistory();
    } finally {
      setRunning(false);
      setProgress("");
    }
  }

  async function backupTableCsv(table: string) {
    if (!isAdmin) {
      toast.error("Accès refusé");
      return;
    }
    try {
      const { assertPermission } = await import("@/lib/rbac-api");
      await assertPermission("backup.exporter_csv");
    } catch (e) {
      toast.error((e as Error).message);
      return;
    }
    try {
      const rows = await fetchTable(table);
      if (!rows.length) {
        toast.info(`Table ${table} vide`);
        return;
      }
      const headers = Object.keys(rows[0]);
      exportCsv(
        `backup_${table}`,
        headers,
        rows.map((r) => headers.map((h) => (r[h] == null ? "" : String(r[h])))),
        {
          pageTitle: `SAUVEGARDE — ${table.toUpperCase()}`,
          summary: [
            { label: "Table sauvegardée", value: table },
            { label: "Enregistrements exportés", value: String(rows.length) },
            { label: "Colonnes", value: String(headers.length) },
            { label: "Date de génération", value: new Date().toLocaleString("fr-FR") },
          ],
        },
      );
    } catch (e) {
      toast.error((e as Error).message);
    }
  }

  if (isAdmin === null) {
    return (
      <div className="flex h-64 items-center justify-center text-muted-foreground">
        <Loader2 className="mr-2 h-5 w-5 animate-spin" /> Vérification des accès…
      </div>
    );
  }
  if (!isAdmin) {
    return (
      <Card className="border-destructive/50">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-destructive">
            <ShieldAlert className="h-5 w-5" /> Accès réservé aux super-administrateurs
          </CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-muted-foreground">
          La sauvegarde et la restauration de l'ERP sont limitées aux comptes disposant du rôle{" "}
          <b>super_admin</b>. Contactez votre administrateur pour obtenir l'accès.
        </CardContent>
      </Card>
    );
  }

  const derniere = history[0];
  const succes = history.filter((h) => h.statut === "succes").length;
  const echecs = history.filter((h) => h.statut === "echec").length;
  const espace = history.reduce((s, h) => s + (h.taille_octets ?? 0), 0);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold">
          <DatabaseBackup className="h-6 w-6 text-primary" /> Sauvegarde &amp; Restauration
        </h1>
        <p className="text-sm text-muted-foreground">
          Administration → Sauvegarde &amp; Restauration — export complet des données de l'ERP
        </p>
      </div>

      {/* Tableau de bord */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <Clock className="h-4 w-4" /> Dernière sauvegarde
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-lg font-semibold">
              {derniere ? new Date(derniere.created_at).toLocaleString("fr-FR") : "—"}
            </div>
            {derniere && (
              <div className="mt-1 text-xs text-muted-foreground">
                {derniere.type} • {formatSize(derniere.taille_octets)}
              </div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <History className="h-4 w-4" /> Sauvegardes
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{history.length}</div>
            <div className="mt-1 text-xs text-muted-foreground">
              <span className="text-emerald-600">{succes} succès</span> ·{" "}
              <span className="text-destructive">{echecs} échecs</span>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <HardDrive className="h-4 w-4" /> Espace utilisé
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatSize(espace)}</div>
            <div className="mt-1 text-xs text-muted-foreground">50 derniers historiques</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <UserIcon className="h-4 w-4" /> Session
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="truncate text-sm font-medium">{userEmail ?? "—"}</div>
            <Badge variant="outline" className="mt-1">
              super_admin
            </Badge>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Sauvegarde complète</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Génère un fichier JSON unique contenant toutes les données des tables principales.
            L'opération est enregistrée dans l'historique et le journal d'audit.
          </p>
          <label className="flex items-center gap-2 text-sm">
            <Checkbox
              checked={sendToDrive}
              onCheckedChange={(v) => setSendToDrive(v === true)}
              disabled={running}
            />
            <Cloud className="h-4 w-4 text-primary" />
            Envoyer aussi vers Google Drive (connecteur atelier)
          </label>
          <div className="text-xs text-muted-foreground">
            <Link to="/admin/google-drive" className="text-primary hover:underline">
              Vérifier / configurer le connecteur Google Drive →
            </Link>
          </div>
          <Button onClick={backupAllJson} disabled={running}>
            {running ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Download className="mr-2 h-4 w-4" />
            )}
            {running ? progress || "Sauvegarde…" : "Créer une sauvegarde maintenant (JSON)"}
          </Button>
        </CardContent>
      </Card>

      <Card className="border-amber-500/40">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ShieldCheck className="h-5 w-5 text-amber-600" />
            Export critique — Comptes & Fichiers
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-sm text-muted-foreground">
            Complète la sauvegarde JSON avec les deux éléments non couverts par le dump SQL :
            la liste des comptes <code>auth.users</code> (id, email, métadonnées, providers) et
            un <b>manifest storage</b> avec URLs signées 7 jours pour tous les buckets
            (product-covers, avatars, exports). Indispensable pour reconstruire l'ERP à
            l'identique sur une autre instance.
          </p>
          <Button onClick={backupCriticalArtifacts} disabled={criticalRunning}>
            {criticalRunning ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Cloud className="mr-2 h-4 w-4" />
            )}
            {criticalRunning
              ? "Export en cours…"
              : "Exporter comptes + fichiers vers Google Drive"}
          </Button>
          {criticalResult && (
            <div className="rounded-md border bg-muted/40 p-3 text-sm space-y-1">
              <div>
                ✅ <b>{criticalResult.users_count}</b> comptes auth exportés ·{" "}
                <b>{criticalResult.files_count}</b> fichiers dans{" "}
                <b>{criticalResult.buckets_count}</b> buckets
              </div>
              <div className="flex flex-wrap gap-3 text-xs">
                {criticalResult.users_drive.url && (
                  <a
                    href={criticalResult.users_drive.url}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-primary hover:underline"
                  >
                    <Cloud className="h-3 w-3" /> auth_users.json
                  </a>
                )}
                {criticalResult.storage_drive.url && (
                  <a
                    href={criticalResult.storage_drive.url}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-primary hover:underline"
                  >
                    <Cloud className="h-3 w-3" /> storage_manifest.json
                  </a>
                )}
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      <Card className="border-emerald-500/40">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Download className="h-5 w-5 text-emerald-600" />
            ZIP binaires Storage (couvertures, avatars, RH)
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-sm text-muted-foreground">
            Contrairement au manifest (URLs signées 7 jours), ce ZIP contient les{" "}
            <b>fichiers binaires réels</b> des buckets métier : <code>product-covers</code>,{" "}
            <code>avatars</code>, <code>employe-photos</code>, <code>employe-documents</code>.
            Nécessaire pour restaurer l'ERP hors ligne au-delà de 7 jours.
          </p>
          <Button onClick={backupBinariesZip} disabled={binariesRunning} variant="outline">
            {binariesRunning ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Download className="mr-2 h-4 w-4" />
            )}
            {binariesRunning
              ? "Compression & upload…"
              : "Exporter ZIP binaires vers Google Drive"}
          </Button>
          {binariesResult && (
            <div className="rounded-md border bg-muted/40 p-3 text-sm space-y-2">
              <div>
                ✅ <b>{binariesResult.total_files}</b> fichiers ·{" "}
                <b>{(binariesResult.zip_bytes / 1024 / 1024).toFixed(1)} Mo</b> compressés
                ({(binariesResult.total_bytes / 1024 / 1024).toFixed(1)} Mo décompressés)
              </div>
              <ul className="text-xs text-muted-foreground space-y-0.5">
                {binariesResult.buckets.map((b) => (
                  <li key={b.bucket}>
                    • <b>{b.bucket}</b> — {b.files} fichiers (
                    {(b.bytes / 1024 / 1024).toFixed(1)} Mo)
                  </li>
                ))}
              </ul>
              {binariesResult.drive.url && (
                <a
                  href={binariesResult.drive.url}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1 text-primary hover:underline text-xs"
                >
                  <Cloud className="h-3 w-3" /> storage_binaries.zip
                </a>
              )}
            </div>
          )}
        </CardContent>
      </Card>


      <BackupSchedulesCard />

      <BackupRestoreCard />

      <Card>
        <CardHeader>
          <CardTitle>Export par table (PDF)</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {TABLES.map((t) => (
              <Button
                key={t}
                variant="outline"
                className="justify-start"
                onClick={() => backupTableCsv(t)}
              >
                <Download className="mr-2 h-4 w-4" />
                {t}
              </Button>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Historique */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <History className="h-5 w-5" /> Historique des sauvegardes
          </CardTitle>
          <Button variant="outline" size="sm" onClick={loadHistory} disabled={loadingHistory}>
            {loadingHistory ? <Loader2 className="h-4 w-4 animate-spin" /> : "Rafraîchir"}
          </Button>
        </CardHeader>
        <CardContent>
          {history.length === 0 ? (
            <p className="text-sm text-muted-foreground">Aucune sauvegarde enregistrée.</p>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Date</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Utilisateur</TableHead>
                    <TableHead>Destination</TableHead>
                    <TableHead>Taille</TableHead>
                    <TableHead>Durée</TableHead>
                    <TableHead>Statut</TableHead>
                    <TableHead>Intégrité</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {history.map((h) => (
                    <TableRow key={h.backup_id}>
                      <TableCell className="text-xs">
                        {new Date(h.created_at).toLocaleString("fr-FR")}
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary">{h.type}</Badge>
                      </TableCell>
                      <TableCell className="text-xs">{h.user_email ?? "—"}</TableCell>
                      <TableCell className="text-xs">
                        {h.destination_url ? (
                          <a
                            href={h.destination_url}
                            target="_blank"
                            rel="noreferrer"
                            className="inline-flex items-center gap-1 text-primary hover:underline"
                          >
                            <Cloud className="h-3 w-3" /> {h.destination}
                          </a>
                        ) : (
                          h.destination
                        )}
                      </TableCell>
                      <TableCell className="text-xs">{formatSize(h.taille_octets)}</TableCell>
                      <TableCell className="text-xs">{formatDuration(h.duree_ms)}</TableCell>
                      <TableCell>
                        {h.statut === "succes" ? (
                          <Badge className="bg-emerald-600 hover:bg-emerald-700">
                            <CheckCircle2 className="mr-1 h-3 w-3" /> Succès
                          </Badge>
                        ) : h.statut === "echec" ? (
                          <Badge variant="destructive">
                            <XCircle className="mr-1 h-3 w-3" /> Échec
                          </Badge>
                        ) : (
                          <Badge variant="outline">
                            <Loader2 className="mr-1 h-3 w-3 animate-spin" /> En cours
                          </Badge>
                        )}
                      </TableCell>
                      <TableCell>
                        {h.verifie ? (
                          <Badge
                            className="bg-sky-600 hover:bg-sky-700"
                            title={h.sha256 ?? undefined}
                          >
                            <ShieldCheck className="mr-1 h-3 w-3" /> SHA-256
                          </Badge>
                        ) : (
                          <Badge variant="outline">—</Badge>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
