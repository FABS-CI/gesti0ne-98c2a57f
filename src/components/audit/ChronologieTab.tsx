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
import { Eye } from "lucide-react";
import { ACTION_LABEL, ACTION_VARIANT, type AuditRow } from "@/lib/audit-helpers";

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

const Row = React.memo(function Row({
  r,
  onSelect,
  onUserClick,
}: {
  r: AuditRow;
  onSelect: (r: AuditRow) => void;
  onUserClick: (email: string) => void;
}) {
  return (
    <TableRow className="hover:bg-muted/40">
      <TableCell className="whitespace-nowrap text-sm">
        {new Date(r.occurred_at).toLocaleString("fr-FR")}
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
      <TableCell className="capitalize">{r.table_name}</TableCell>
      <TableCell className="font-mono text-xs text-muted-foreground">
        {r.record_ref ?? r.record_id ?? "—"}
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
    <div className="rounded-lg border bg-card">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Date & heure</TableHead>
            <TableHead>Utilisateur</TableHead>
            <TableHead>Action</TableHead>
            <TableHead>Module</TableHead>
            <TableHead>Référence</TableHead>
            <TableHead className="w-24"></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading ? (
            <TableRow>
              <TableCell colSpan={6} className="py-10 text-center text-muted-foreground">
                Chargement…
              </TableCell>
            </TableRow>
          ) : rows.length === 0 ? (
            <TableRow>
              <TableCell colSpan={6} className="py-10 text-center text-muted-foreground">
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
