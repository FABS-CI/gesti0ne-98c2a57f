import React from "react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Eye, Monitor, Smartphone, Tablet } from "lucide-react";
import {
  ACTION_LABEL,
  ACTION_VARIANT,
  CRITICITE_STYLE,
  STATUS_STYLE,
  type AuditRow,
} from "@/lib/audit-helpers";

type Props = {
  rows: AuditRow[];
  isLoading: boolean;
  onSelect: (r: AuditRow) => void;
  onUserClick: (email: string) => void;
  page?: number;
  pageSize?: number;
  totalCount?: number;
  onPageChange?: (page: number) => void;
};

function DeviceIcon({ device }: { device?: string | null }) {
  if (device === "Mobile") return <Smartphone className="h-3.5 w-3.5" />;
  if (device === "Tablette") return <Tablet className="h-3.5 w-3.5" />;
  return <Monitor className="h-3.5 w-3.5" />;
}

const Row = React.memo(function Row({
  r,
  onSelect,
  onUserClick,
}: {
  r: AuditRow;
  onSelect: (r: AuditRow) => void;
  onUserClick: (email: string) => void;
}) {
  const crit = CRITICITE_STYLE[r.criticite ?? "info"] ?? CRITICITE_STYLE.info;
  const stat = STATUS_STYLE[r.status ?? "success"] ?? STATUS_STYLE.success;
  const localisation = [r.city, r.country].filter(Boolean).join(", ");
  const navigateur = [r.browser, r.browser_version].filter(Boolean).join(" ");
  return (
    <TableRow className="hover:bg-muted/40">
      <TableCell className="whitespace-nowrap text-xs">
        <div>{new Date(r.occurred_at).toLocaleDateString("fr-FR")}</div>
        <div className="text-muted-foreground">
          {new Date(r.occurred_at).toLocaleTimeString("fr-FR", { hour12: false })}
        </div>
      </TableCell>
      <TableCell>
        <button
          className="font-medium text-primary hover:underline"
          onClick={() => onUserClick(r.user_email ?? "")}
        >
          {r.user_email || "—"}
        </button>
      </TableCell>
      <TableCell>
        <Badge variant={ACTION_VARIANT(r.action)}>{ACTION_LABEL[r.action] ?? r.action}</Badge>
      </TableCell>
      <TableCell className="capitalize text-xs">{r.table_name}</TableCell>
      <TableCell className="font-mono text-xs text-muted-foreground max-w-[180px] truncate">
        {r.record_ref ?? r.record_id ?? "—"}
      </TableCell>
      <TableCell>
        <span className={`inline-flex rounded px-1.5 py-0.5 text-xs font-medium ${stat.className}`}>
          {stat.label}
        </span>
      </TableCell>
      <TableCell>
        <span className={`inline-flex rounded px-1.5 py-0.5 text-xs font-medium ${crit.className}`}>
          {crit.label}
        </span>
      </TableCell>
      <TableCell className="text-xs text-muted-foreground">
        <div className="flex items-center gap-1.5">
          <DeviceIcon device={r.device} />
          <span className="truncate max-w-[110px]" title={navigateur}>
            {navigateur || "—"}
          </span>
        </div>
        <div className="text-[10px] text-muted-foreground">{r.os ?? ""}</div>
      </TableCell>
      <TableCell className="text-xs">
        <div className="font-mono">{r.ip_address ?? "—"}</div>
        {localisation && <div className="text-muted-foreground">{localisation}</div>}
      </TableCell>
      <TableCell className="text-xs text-muted-foreground">
        {r.duration_ms != null ? `${r.duration_ms} ms` : "—"}
      </TableCell>
      <TableCell>
        <Button variant="ghost" size="sm" onClick={() => onSelect(r)}>
          <Eye className="mr-1 h-4 w-4" /> Détail
        </Button>
      </TableCell>
    </TableRow>
  );
});

export function ChronologieTab({
  rows,
  isLoading,
  onSelect,
  onUserClick,
  page,
  pageSize,
  totalCount,
  onPageChange,
}: Props) {
  const showPager = page && pageSize && totalCount !== undefined && onPageChange;
  const totalPages = showPager ? Math.max(1, Math.ceil(totalCount / pageSize)) : 1;
  return (
    <div className="rounded-lg border bg-card overflow-x-auto">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Date / Heure</TableHead>
            <TableHead>Utilisateur</TableHead>
            <TableHead>Action</TableHead>
            <TableHead>Module</TableHead>
            <TableHead>Référence</TableHead>
            <TableHead>Résultat</TableHead>
            <TableHead>Niveau</TableHead>
            <TableHead>Appareil</TableHead>
            <TableHead>IP / Localisation</TableHead>
            <TableHead>Durée</TableHead>
            <TableHead className="w-24"></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading ? (
            <TableRow>
              <TableCell colSpan={11} className="py-10 text-center text-muted-foreground">
                Chargement…
              </TableCell>
            </TableRow>
          ) : rows.length === 0 ? (
            <TableRow>
              <TableCell colSpan={11} className="py-10 text-center text-muted-foreground">
                Aucun événement
              </TableCell>
            </TableRow>
          ) : (
            rows.map((r) => <Row key={r.id} r={r} onSelect={onSelect} onUserClick={onUserClick} />)
          )}
        </TableBody>
      </Table>
      {showPager && totalCount > 0 && (
        <div className="flex items-center justify-between border-t px-4 py-3 text-sm text-muted-foreground">
          <span>
            {(page - 1) * pageSize + 1}–{Math.min(page * pageSize, totalCount)} sur {totalCount}
          </span>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              disabled={page <= 1 || isLoading}
              onClick={() => onPageChange(page - 1)}
            >
              Précédent
            </Button>
            <span className="px-2 py-1">
              Page {page} / {totalPages}
            </span>
            <Button
              variant="outline"
              size="sm"
              disabled={page >= totalPages || isLoading}
              onClick={() => onPageChange(page + 1)}
            >
              Suivant
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
