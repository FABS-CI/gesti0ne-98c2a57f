import { useState } from "react";
import { Loader2, RefreshCcw } from "lucide-react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

export function SyncRbacButton() {
  const [loading, setLoading] = useState(false);
  const [report, setReport] = useState<Record<string, unknown> | null>(null);

  async function run() {
    setLoading(true);
    const { data, error } = await supabase.rpc("sync_rbac_matrix");
    setLoading(false);
    if (error) {
      toast.error("Synchronisation refusée", { description: error.message });
      return;
    }
    setReport(data as Record<string, unknown>);
    toast.success("Synchronisation terminée", {
      description: `${(data as Record<string, unknown>)?.permissions ?? 0} permissions, ${
        (data as Record<string, unknown>)?.roles_actifs ?? 0
      } rôles actifs`,
    });
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" onClick={run} disabled={loading}>
          {loading ? (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          ) : (
            <RefreshCcw className="mr-2 h-4 w-4" />
          )}
          Synchroniser
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Rapport de synchronisation RBAC</DialogTitle>
        </DialogHeader>
        {report ? (
          <div className="space-y-2 text-sm">
            {Object.entries(report).map(([k, v]) => (
              <div key={k} className="flex justify-between border-b py-1">
                <span className="text-muted-foreground">{k}</span>
                <span className="font-mono">{String(v)}</span>
              </div>
            ))}
            <p className="pt-2 text-xs text-muted-foreground">
              Aucun droit accordé n'a été modifié. Les nouvelles entrées apparaissent comme Refusé
              par défaut et doivent être accordées manuellement.
            </p>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">Lancement de la synchronisation…</p>
        )}
      </DialogContent>
    </Dialog>
  );
}
