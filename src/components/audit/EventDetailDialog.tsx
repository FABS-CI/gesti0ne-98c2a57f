import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Badge } from "@/components/ui/badge";
import { ACTION_LABEL, ACTION_VARIANT, type AuditRow } from "@/lib/audit-helpers";

type Props = { selected: AuditRow | null; onClose: () => void };

function Meta({
  label,
  value,
  className,
}: {
  label: string;
  value: string | null | undefined;
  className?: string;
}) {
  return (
    <div className={className}>
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">{label}</div>
      <div className="truncate font-mono text-xs">{value || "—"}</div>
    </div>
  );
}

export function EventDetailDialog({ selected, onClose }: Props) {
  return (
    <Dialog open={!!selected} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-3xl">
        <DialogHeader>
          <DialogTitle>Détail de l'événement</DialogTitle>
          <DialogDescription asChild>
            {selected ? (
              <div className="flex flex-wrap items-center gap-2 text-sm">
                <span>{new Date(selected.occurred_at).toLocaleString("fr-FR")}</span>
                <span>·</span>
                <span className="font-medium">{selected.user_email || "—"}</span>
                <span>·</span>
                <Badge variant={ACTION_VARIANT(selected.action)}>
                  {ACTION_LABEL[selected.action] ?? selected.action}
                </Badge>
                <span>
                  sur <span className="capitalize">{selected.table_name}</span>
                </span>
              </div>
            ) : (
              <span />
            )}
          </DialogDescription>
        </DialogHeader>
        {selected && (
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="grid grid-cols-2 gap-2 text-xs sm:col-span-2">
              <Meta label="Module" value={selected.module ?? selected.table_name} />
              <Meta label="Référence" value={selected.record_ref ?? selected.record_id} />
              <Meta label="URL" value={selected.url} />
              <Meta label="Méthode" value={selected.http_method} />
              <Meta label="Adresse IP" value={selected.ip_address} />
              <Meta
                label="Durée"
                value={selected.duration_ms != null ? `${selected.duration_ms} ms` : null}
              />
              <Meta label="Statut" value={selected.status} />
              <Meta label="User agent" value={selected.user_agent} className="col-span-2" />
            </div>
            {selected.changes ? (
              <div className="sm:col-span-2">
                <div className="mb-2 text-xs font-semibold uppercase text-muted-foreground">
                  Champs modifiés
                </div>
                <ScrollArea className="h-40 rounded border bg-muted/30 p-3">
                  <pre className="text-xs">{JSON.stringify(selected.changes, null, 2)}</pre>
                </ScrollArea>
              </div>
            ) : null}
            <div>
              <div className="mb-2 text-xs font-semibold uppercase text-muted-foreground">
                Avant
              </div>
              <ScrollArea className="h-80 rounded border bg-muted/30 p-3">
                <pre className="text-xs">
                  {selected.old_values ? JSON.stringify(selected.old_values, null, 2) : "—"}
                </pre>
              </ScrollArea>
            </div>
            <div>
              <div className="mb-2 text-xs font-semibold uppercase text-muted-foreground">
                Après
              </div>
              <ScrollArea className="h-80 rounded border bg-muted/30 p-3">
                <pre className="text-xs">
                  {selected.new_values ? JSON.stringify(selected.new_values, null, 2) : "—"}
                </pre>
              </ScrollArea>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
