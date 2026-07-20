import { useCallback, useEffect, useState } from "react";
import { toast } from "sonner";
import { RefreshCcw, Loader2, CheckCircle2, AlertTriangle, PackagePlus, Boxes } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { friendlyError } from "@/lib/friendly-error";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { ROUTE_TO_PERMISSION } from "@/lib/route-permissions";

type SyncReport = {
  applied: boolean;
  inventory_size: number;
  created_resources: Array<{ code: string; module_code: string }>;
  created_permissions: Array<{ code: string; resource_code: string; action: string }>;
  orphan_permissions: Array<{ code: string; label: string }>;
  orphan_resources: Array<{ code: string; label: string }>;
  unmapped_routes: string[];
  rpcs: Array<{ name: string; security_definer: boolean }>;
  generated_at: string;
};

function buildInventory() {
  const permissions = new Set<string>();
  const unmapped: string[] = [];
  for (const [route, req] of Object.entries(ROUTE_TO_PERMISSION)) {
    if (req == null) continue;
    if (typeof req === "string") permissions.add(req);
    else if (Array.isArray(req)) req.forEach((p) => permissions.add(p));
    else unmapped.push(route);
  }
  return {
    permissions: Array.from(permissions).sort(),
    unmapped_routes: unmapped,
  };
}

export function SyncCatalogDialog({
  open,
  onOpenChange,
  onApplied,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onApplied: () => void;
}) {
  const [loading, setLoading] = useState(false);
  const [applying, setApplying] = useState(false);
  const [report, setReport] = useState<SyncReport | null>(null);

  const run = useCallback(async (apply: boolean) => {
    const setter = apply ? setApplying : setLoading;
    setter(true);
    try {
      const { data, error } = await supabase.rpc("rbac2_sync_catalog", {
        _inventory: buildInventory(),
        _apply: apply,
      });
      if (error) throw error;
      setReport(data as unknown as SyncReport);
      if (apply) {
        toast.success("Catalogue synchronisé", {
          description: `${(data as unknown as SyncReport).created_permissions.length} permissions créées`,
        });
        onApplied();
      }
    } catch (e) {
      toast.error(friendlyError(e));
    } finally {
      setter(false);
    }
  }, [onApplied]);

  useEffect(() => { if (open && !report) void run(false); }, [open, report, run]);
  useEffect(() => { if (!open) setReport(null); }, [open]);

  const totalNew = report ? report.created_resources.length + report.created_permissions.length : 0;
  const nothingToDo = report && totalNew === 0;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <RefreshCcw className="h-5 w-5 text-primary" />
            Synchronisation du catalogue
            {report && (
              <Badge variant={totalNew > 0 ? "default" : "secondary"} className="ml-2">
                {totalNew} nouveauté{totalNew > 1 ? "s" : ""}
              </Badge>
            )}
          </DialogTitle>
          <DialogDescription>
            Comparaison entre les permissions déclarées dans l'application (routes) et le catalogue RBAC v2.
            Aucun droit accordé n'est modifié ; les nouvelles permissions apparaissent comme <em>refusées par défaut</em>.
          </DialogDescription>
        </DialogHeader>

        {loading && (
          <div className="py-10 flex flex-col items-center gap-2 text-muted-foreground">
            <Loader2 className="h-6 w-6 animate-spin" />
            <div>Analyse en cours…</div>
          </div>
        )}

        {!loading && report && (
          <ScrollArea className="max-h-[60vh]">
            <div className="space-y-3 pr-3">
              <div className="text-sm text-muted-foreground">
                Inventaire : <strong>{report.inventory_size}</strong> permissions déclarées côté application ·
                <strong> {report.rpcs.length}</strong> RPC publiques détectées.
              </div>

              {nothingToDo && (
                <div className="py-6 text-center text-emerald-600 flex flex-col items-center gap-2">
                  <CheckCircle2 className="h-8 w-8" />
                  <div className="font-medium">Catalogue à jour — aucune ressource ni permission à créer.</div>
                </div>
              )}

              <Section
                icon={<PackagePlus className="h-4 w-4 text-emerald-600" />}
                title="Ressources à créer"
                rows={report.created_resources}
                render={(r: { code: string; module_code: string }) => (
                  <span><code>{r.code}</code> <span className="text-muted-foreground">→ module {r.module_code}</span></span>
                )}
              />

              <Section
                icon={<PackagePlus className="h-4 w-4 text-emerald-600" />}
                title="Permissions à créer"
                rows={report.created_permissions}
                render={(p: { code: string; resource_code: string; action: string }) => (
                  <span><code>{p.code}</code> <Badge variant="outline" className="ml-2 text-[10px]">{p.action}</Badge></span>
                )}
              />

              <Section
                icon={<AlertTriangle className="h-4 w-4 text-amber-600" />}
                title="Permissions orphelines (dans le catalogue, jamais utilisées par l'app)"
                rows={report.orphan_permissions}
                collapsedByDefault
                render={(p: { code: string; label: string }) => (
                  <span><code>{p.code}</code> <span className="text-muted-foreground">— {p.label}</span></span>
                )}
              />

              <Section
                icon={<Boxes className="h-4 w-4 text-amber-600" />}
                title="Ressources orphelines"
                rows={report.orphan_resources}
                collapsedByDefault
                render={(r: { code: string; label: string }) => (
                  <span><code>{r.code}</code> <span className="text-muted-foreground">— {r.label}</span></span>
                )}
              />

              {report.unmapped_routes.length > 0 && (
                <Section
                  icon={<AlertTriangle className="h-4 w-4 text-amber-600" />}
                  title="Routes sans permission requise (libres)"
                  rows={report.unmapped_routes.map((r) => ({ path: r }))}
                  collapsedByDefault
                  render={(r: { path: string }) => <code>{r.path}</code>}
                />
              )}
            </div>
          </ScrollArea>
        )}

        <DialogFooter className="gap-2">
          <Button variant="ghost" onClick={() => onOpenChange(false)}>Fermer</Button>
          <Button variant="outline" disabled={loading || applying} onClick={() => run(false)}>
            {loading ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <RefreshCcw className="h-4 w-4 mr-2" />}
            Relancer l'analyse
          </Button>
          <Button disabled={loading || applying || !report || totalNew === 0} onClick={() => run(true)}>
            {applying ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <PackagePlus className="h-4 w-4 mr-2" />}
            Appliquer ({totalNew})
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Section<T>({
  icon, title, rows, render, collapsedByDefault,
}: {
  icon: React.ReactNode;
  title: string;
  rows: T[];
  render: (row: T) => React.ReactNode;
  collapsedByDefault?: boolean;
}) {
  const [open, setOpen] = useState(!collapsedByDefault);
  if (!rows || rows.length === 0) return null;
  return (
    <div className="border rounded-md">
      <button
        onClick={() => setOpen((v) => !v)}
        className="w-full px-3 py-2 border-b bg-muted/40 flex items-center gap-2 text-sm font-medium text-left hover:bg-muted"
      >
        {icon}
        {title}
        <Badge variant="outline" className="ml-auto">{rows.length}</Badge>
      </button>
      {open && (
        <ul className="p-2 space-y-1 text-sm">
          {rows.slice(0, 50).map((r, i) => (
            <li key={i} className="px-2 py-1 rounded hover:bg-muted">{render(r)}</li>
          ))}
          {rows.length > 50 && (
            <li className="px-2 py-1 text-xs italic text-muted-foreground">
              … {rows.length - 50} autres non affichés
            </li>
          )}
        </ul>
      )}
    </div>
  );
}
