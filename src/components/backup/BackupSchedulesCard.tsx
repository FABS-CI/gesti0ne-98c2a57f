import { getCurrentUser } from "@/lib/current-user";
import { useEffect, useState } from "react";
import { CalendarClock, Loader2, Plus, Trash2, Trash } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Can } from "@/components/rbac/Can";
import {
import { friendlyError } from "@/lib/friendly-error";
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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

type Frequence = "horaire" | "quotidien" | "hebdomadaire" | "mensuel";
type TypeSauv = "complete" | "base" | "documents";
type Destination =
  "local" | "google_drive" | "onedrive" | "dropbox" | "s3" | "b2" | "wasabi" | "r2" | "ftp" | "nas";

type Schedule = {
  schedule_id: string;
  nom: string;
  frequence: Frequence;
  type_sauvegarde: TypeSauv;
  destination: Destination;
  active: boolean;
  retention_count: number;
  last_run_at: string | null;
  next_run_at: string | null;
};

const FREQ_MS: Record<Frequence, number> = {
  horaire: 60 * 60 * 1000,
  quotidien: 24 * 60 * 60 * 1000,
  hebdomadaire: 7 * 24 * 60 * 60 * 1000,
  mensuel: 30 * 24 * 60 * 60 * 1000,
};

function nextRun(freq: Frequence, from = new Date()) {
  return new Date(from.getTime() + FREQ_MS[freq]).toISOString();
}

export function BackupSchedulesCard() {
  const [items, setItems] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [purging, setPurging] = useState(false);
  const [form, setForm] = useState({
    nom: "Sauvegarde quotidienne",
    frequence: "quotidien" as Frequence,
    type_sauvegarde: "complete" as TypeSauv,
    destination: "local" as Destination,
    retention_count: 10,
    active: true,
  });

  async function load() {
    setLoading(true);
    const { data, error } = await supabase
      .from("backup_schedules")
      .select("*")
      .order("created_at", { ascending: false });
    setLoading(false);
    if (error) {
      toast.error(friendlyError(error));
      return;
    }
    setItems((data ?? []) as Schedule[]);
  }
  useEffect(() => {
    load();
  }, []);

  async function save() {
    setSaving(true);
    const { data: userData } = await getCurrentUser();
    const payload = {
      ...form,
      created_by: userData.user?.id ?? null,
      next_run_at: nextRun(form.frequence),
    };
    const { error } = await supabase.from("backup_schedules").insert(payload);
    setSaving(false);
    if (error) {
      toast.error(friendlyError(error));
      return;
    }
    toast.success("Planification créée");
    setOpen(false);
    load();
  }

  async function toggle(s: Schedule) {
    const { error } = await supabase
      .from("backup_schedules")
      .update({ active: !s.active })
      .eq("schedule_id", s.schedule_id);
    if (error) toast.error(friendlyError(error));
    else load();
  }

  async function remove(id: string) {
    const { error } = await supabase.from("backup_schedules").delete().eq("schedule_id", id);
    if (error) toast.error(friendlyError(error));
    else {
      toast.success("Planification supprimée");
      load();
    }
  }

  async function purge(type: TypeSauv | null, retention: number) {
    setPurging(true);
    const { data, error } = await supabase.rpc("purger_anciennes_sauvegardes", {
      _type: type ?? undefined,
      _retention: retention,
    });
    setPurging(false);
    if (error) {
      toast.error(friendlyError(error));
      return;
    }
    toast.success(`${data ?? 0} sauvegarde(s) supprimée(s)`);
  }

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle className="flex items-center gap-2">
          <CalendarClock className="h-5 w-5" /> Planification automatique &amp; rétention
        </CardTitle>
        <div className="flex gap-2">
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button variant="outline" size="sm" disabled={purging}>
                {purging ? (
                  <Loader2 className="mr-1 h-4 w-4 animate-spin" />
                ) : (
                  <Trash className="mr-1 h-4 w-4" />
                )}
                Purger (retention 10)
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Purger les anciennes sauvegardes ?</AlertDialogTitle>
                <AlertDialogDescription>
                  Conserve les <b>10 dernières</b> sauvegardes réussies par type. Les plus anciennes
                  seront supprimées de l'historique. Cette action est enregistrée dans le journal
                  d'audit.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Annuler</AlertDialogCancel>
                <AlertDialogAction onClick={() => purge(null, 10)}>Purger</AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
          <Button size="sm" onClick={() => setOpen(true)}>
            <Plus className="mr-1 h-4 w-4" /> Nouvelle planification
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        <p className="mb-3 text-xs text-muted-foreground">
          Configurez ici les sauvegardes récurrentes et le nombre de versions à conserver. Le
          déclenchement effectif nécessite un job cron côté serveur (à raccorder ensuite) ; en
          attendant, cette configuration pilote la <b>purge automatique</b> et l'affichage du{" "}
          <b>prochain passage</b>.
        </p>
        {loading ? (
          <div className="flex justify-center py-6">
            <Loader2 className="h-5 w-5 animate-spin" />
          </div>
        ) : items.length === 0 ? (
          <p className="text-sm text-muted-foreground">Aucune planification configurée.</p>
        ) : (
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nom</TableHead>
                  <TableHead>Fréquence</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Destination</TableHead>
                  <TableHead>Retention</TableHead>
                  <TableHead>Prochaine</TableHead>
                  <TableHead>Active</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((s) => (
                  <TableRow key={s.schedule_id}>
                    <TableCell className="font-medium">{s.nom}</TableCell>
                    <TableCell>
                      <Badge variant="secondary">{s.frequence}</Badge>
                    </TableCell>
                    <TableCell className="text-xs">{s.type_sauvegarde}</TableCell>
                    <TableCell className="text-xs">{s.destination}</TableCell>
                    <TableCell className="text-xs">{s.retention_count}</TableCell>
                    <TableCell className="text-xs">
                      {s.next_run_at ? new Date(s.next_run_at).toLocaleString("fr-FR") : "—"}
                    </TableCell>
                    <TableCell>
                      <Switch checked={s.active} onCheckedChange={() => toggle(s)} />
                    </TableCell>
                    <TableCell className="text-right space-x-1">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => purge(s.type_sauvegarde, s.retention_count)}
                        title={`Purger au-delà de ${s.retention_count} pour type ${s.type_sauvegarde}`}
                      >
                        <Trash className="h-3 w-3" />
                      </Button>
                      <Can permission="backup.supprimer">
                        <AlertDialog>
                          <AlertDialogTrigger asChild>
                            <Button variant="ghost" size="sm">
                              <Trash2 className="h-4 w-4 text-destructive" />
                            </Button>
                          </AlertDialogTrigger>
                          <AlertDialogContent>
                          <AlertDialogHeader>
                              <AlertDialogTitle>Supprimer cette planification ?</AlertDialogTitle>
                              <AlertDialogDescription>
                              La configuration « {s.nom} » sera définitivement retirée. Les
                              sauvegardes déjà générées ne sont pas affectées.
                              </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                              <AlertDialogCancel>Annuler</AlertDialogCancel>
                              <AlertDialogAction onClick={() => remove(s.schedule_id)}>
                                Supprimer
                              </AlertDialogAction>
                            </AlertDialogFooter>
                          </AlertDialogContent>
                        </AlertDialog>
                      </Can>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </CardContent>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Nouvelle planification</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1">
              <Label>Nom</Label>
              <Input
                value={form.nom}
                onChange={(e) => setForm((f) => ({ ...f, nom: e.target.value }))}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Fréquence</Label>
                <Select
                  value={form.frequence}
                  onValueChange={(v) => setForm((f) => ({ ...f, frequence: v as Frequence }))}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="horaire">Toutes les heures</SelectItem>
                    <SelectItem value="quotidien">Chaque nuit</SelectItem>
                    <SelectItem value="hebdomadaire">Chaque semaine</SelectItem>
                    <SelectItem value="mensuel">Chaque mois</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Type</Label>
                <Select
                  value={form.type_sauvegarde}
                  onValueChange={(v) => setForm((f) => ({ ...f, type_sauvegarde: v as TypeSauv }))}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="complete">Complète</SelectItem>
                    <SelectItem value="base">Base uniquement</SelectItem>
                    <SelectItem value="documents">Documents</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Destination</Label>
                <Select
                  value={form.destination}
                  onValueChange={(v) => setForm((f) => ({ ...f, destination: v as Destination }))}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="local">Local (téléchargement)</SelectItem>
                    <SelectItem value="google_drive">Google Drive</SelectItem>
                    <SelectItem value="onedrive">OneDrive</SelectItem>
                    <SelectItem value="dropbox">Dropbox</SelectItem>
                    <SelectItem value="s3">Amazon S3</SelectItem>
                    <SelectItem value="b2">Backblaze B2</SelectItem>
                    <SelectItem value="wasabi">Wasabi</SelectItem>
                    <SelectItem value="r2">Cloudflare R2</SelectItem>
                    <SelectItem value="ftp">FTP/SFTP</SelectItem>
                    <SelectItem value="nas">NAS local</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Versions à conserver</Label>
                <Input
                  type="number"
                  min={1}
                  max={500}
                  value={form.retention_count}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, retention_count: Number(e.target.value) || 10 }))
                  }
                />
              </div>
            </div>
            <div className="flex items-center justify-between rounded-md border p-3">
              <div>
                <Label>Active</Label>
                <p className="text-xs text-muted-foreground">
                  La planification sera prise en compte par le job cron.
                </p>
              </div>
              <Switch
                checked={form.active}
                onCheckedChange={(v) => setForm((f) => ({ ...f, active: v }))}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Annuler
            </Button>
            <Button onClick={save} disabled={saving}>
              {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />} Enregistrer
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
