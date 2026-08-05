import { getCurrentUser } from "@/lib/current-user";
import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import {
  DatabaseBackup,
  Download,
  Loader2,
  HardDrive,
  Clock,
  CheckCircle2,
  XCircle,
  History,
  ShieldCheck,
  Cloud,
  Play,
  RotateCcw,
  ShieldAlert,
  AlertTriangle,
} from "lucide-react";

import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useServerFn } from "@tanstack/react-start";
import { runFullBackup, runFullRestore } from "@/lib/backup.functions";
import { friendlyError } from "@/lib/friendly-error";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";

export const Route = createFileRoute("/_authenticated/backup")({
  component: BackupPage,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

type BackupRow = {
  backup_id: string;
  created_at: string;
  finished_at: string | null;
  user_email: string | null;
  type: string;
  destination: string;
  statut: string;
  taille_octets: number | null;
  duree_ms: number | null;
  nb_tables: number | null;
  nb_enregistrements: number | null;
  fichier_nom: string | null;
  message: string | null;
  sha256: string | null;
  destination_url: string | null;
};

function formatSize(n: number | null) {
  if (!n) return "—";
  if (n < 1024) return `${n} o`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} Ko`;
  return `${(n / (1024 * 1024)).toFixed(2)} Mo`;
}

function BackupPage() {
  const [running, setRunning] = useState(false);
  const [restoring, setRestoring] = useState<string | null>(null);
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);
  const [history, setHistory] = useState<BackupRow[]>([]);
  const [loadingHistory, setLoadingHistory] = useState(false);
  
  const startBackup = useServerFn(runFullBackup);
  const startRestore = useServerFn(runFullRestore);

  useEffect(() => {
    (async () => {
      const { data: userData } = await getCurrentUser();
      if (!userData.user) {
        setIsAdmin(false);
        return;
      }
      const { data, error } = await supabase.rpc("has_role_compat", {
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
      .limit(20);
    setLoadingHistory(false);
    if (error) {
      toast.error(friendlyError(error));
      return;
    }
    setHistory((data ?? []) as BackupRow[]);
  }

  useEffect(() => {
    if (isAdmin) loadHistory();
  }, [isAdmin]);

  async function handleBackup() {
    setRunning(true);
    try {
      await startBackup({ data: { trigger: "manuel" } });
      toast.success("Sauvegarde intégrale réussie (Local + Cloud)");
      loadHistory();
    } catch (e) {
      toast.error(friendlyError(e));
    } finally {
      setRunning(false);
    }
  }

  async function handleRestore(backup: BackupRow) {
    if (!confirm(`ATTENTION : Vous allez restaurer l'ERP à l'état du ${new Date(backup.created_at).toLocaleString()}. Cette action peut écraser des données récentes. Continuer ?`)) return;
    
    setRestoring(backup.backup_id);
    try {
      const result = await startRestore({ data: { backupId: backup.backup_id } });
      toast.success(`Restauration terminée : ${result.tables.length} tables, ${result.users} comptes, ${result.files} fichiers.`);
    } catch (e) {
      toast.error(friendlyError(e));
    } finally {
      setRestoring(null);
    }
  }

  if (isAdmin === false) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-4">
        <ShieldAlert className="h-12 w-12 text-destructive" />
        <h1 className="text-2xl font-bold">Accès réservé aux administrateurs</h1>
        <p className="text-muted-foreground">Vous n'avez pas les permissions nécessaires pour accéder aux sauvegardes.</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 space-y-8 max-w-6xl">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-3">
            <DatabaseBackup className="h-8 w-8 text-primary" />
            Sauvegarde & Restauration
          </h1>
          <p className="text-muted-foreground mt-1">
            Gestion intégrale de la sécurité de vos données (Données + Fichiers + Comptes).
          </p>
        </div>
        <Button 
          size="lg" 
          onClick={handleBackup} 
          disabled={running}
          className="bg-primary hover:bg-primary/90 text-primary-foreground font-bold shadow-lg"
        >
          {running ? (
            <Loader2 className="mr-2 h-5 w-5 animate-spin" />
          ) : (
            <Play className="mr-2 h-5 w-5 fill-current" />
          )}
          SAUVEGARDER MAINTENANT
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="border-green-500/20 bg-green-50/30 dark:bg-green-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Cloud className="h-4 w-4 text-green-600" />
              Destination Cloud
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-700">Google Drive</div>
            <p className="text-xs text-muted-foreground mt-1">Sauvegardes archivées sur le Drive sécurisé.</p>
          </CardContent>
        </Card>

        <Card className="border-blue-500/20 bg-blue-50/30 dark:bg-blue-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <HardDrive className="h-4 w-4 text-blue-600" />
              Destination Locale
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-700">Serveur ERP</div>
            <p className="text-xs text-muted-foreground mt-1">Copie rapide stockée sur le système de fichiers.</p>
          </CardContent>
        </Card>

        <Card className="border-orange-500/20 bg-orange-50/30 dark:bg-orange-950/10">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium flex items-center gap-2">
              <Clock className="h-4 w-4 text-orange-600" />
              Automatisation
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-700">Toutes les 3h</div>
            <p className="text-xs text-muted-foreground mt-1">Prochaine exécution automatique planifiée.</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <History className="h-5 w-5" />
            Historique des sauvegardes
          </CardTitle>
          <CardDescription>
            Liste des dernières sauvegardes globales effectuées.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="rounded-md border overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow className="bg-muted/50">
                  <TableHead>Date / Heure</TableHead>
                  <TableHead>Fichier</TableHead>
                  <TableHead>Taille</TableHead>
                  <TableHead>Contenu</TableHead>
                  <TableHead>Statut</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {loadingHistory ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center">
                      <Loader2 className="h-6 w-6 animate-spin mx-auto text-muted-foreground" />
                    </TableCell>
                  </TableRow>
                ) : history.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center text-muted-foreground">
                      Aucun historique disponible.
                    </TableCell>
                  </TableRow>
                ) : (
                  history.map((row) => (
                    <TableRow key={row.backup_id} className="group">
                      <TableCell className="font-medium whitespace-nowrap">
                        {new Date(row.created_at).toLocaleString("fr-FR")}
                      </TableCell>
                      <TableCell className="max-w-[200px] truncate" title={row.fichier_nom || ""}>
                        {row.fichier_nom || "—"}
                      </TableCell>
                      <TableCell className="whitespace-nowrap">
                        {formatSize(row.taille_octets)}
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {row.nb_tables || 0} tables / {row.nb_enregistrements || 0} lignes
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          {row.statut === "succes" ? (
                            <>
                              <CheckCircle2 className="h-4 w-4 text-green-600" />
                              <Badge variant="outline" className="text-green-700 bg-green-50 border-green-200">Succès</Badge>
                            </>
                          ) : row.statut === "echec" ? (
                            <>
                              <XCircle className="h-4 w-4 text-destructive" />
                              <Badge variant="destructive">Échec</Badge>
                            </>
                          ) : (
                            <>
                              <Loader2 className="h-4 w-4 animate-spin text-primary" />
                              <Badge variant="secondary">En cours</Badge>
                            </>
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="text-right space-x-2">
                        {row.destination_url && (
                          <Button variant="ghost" size="sm" asChild>
                            <a href={row.destination_url} target="_blank" rel="noopener noreferrer">
                              <Download className="h-4 w-4" />
                            </a>
                          </Button>
                        )}
                        <Button 
                          variant="outline" 
                          size="sm" 
                          onClick={() => handleRestore(row)}
                          disabled={row.statut !== "succes" || !!restoring}
                          className="hover:bg-amber-50 hover:text-amber-700 hover:border-amber-200"
                        >
                          {restoring === row.backup_id ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <RotateCcw className="h-4 w-4 mr-1" />
                          )}
                          Restaurer
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      <Card className="border-amber-500/40 bg-amber-50/30">
        <CardHeader>
          <CardTitle className="text-amber-800 flex items-center gap-2">
            <AlertTriangle className="h-5 w-5" />
            Zone de Danger : Restauration Manuelle
          </CardTitle>
          <CardDescription className="text-amber-700">
            Utilisez cette section uniquement si vous avez un fichier de sauvegarde (.zip) externe à importer.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-4">
            <label className="flex-1 flex flex-col items-center justify-center border-2 border-dashed border-amber-300 rounded-lg p-6 bg-white cursor-pointer hover:bg-amber-50 transition-colors">
              <Download className="h-8 w-8 text-amber-500 mb-2" />
              <span className="text-sm font-medium">Glissez ou cliquez pour importer une archive globale (.zip)</span>
              <input 
                type="file" 
                accept=".zip" 
                className="hidden" 
                onChange={async (e) => {
                  const file = e.target.files?.[0];
                  if (!file) return;
                  if (!confirm("Attention : l'import d'un fichier externe va modifier les données de l'ERP. Continuer ?")) return;
                  
                  const reader = new FileReader();
                  reader.onload = async () => {
                    const base64 = (reader.result as string).split(',')[1];
                    setRestoring("external");
                    try {
                      const res = await startRestore({ data: { base64, fileName: file.name } });
                      toast.success(`Import réussi : ${res.tables.length} tables restaurées.`);
                      loadHistory();
                    } catch (err) {
                      toast.error(friendlyError(err));
                    } finally {
                      setRestoring(null);
                    }
                  };
                  reader.readAsDataURL(file);
                }}
              />
            </label>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
