import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ResponsiveTable } from "@/components/layout/ResponsiveTable";
import { useAuditLogQuery } from "@/hooks/use-roles-permissions";
import React, { useEffect, useMemo, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

function DiffCell({
  avant,
  apres,
  details,
}: {
  avant?: Record<string, unknown> | null;
  apres?: Record<string, unknown> | null;
  details: Record<string, unknown> | null;
}) {
  if (!avant && !apres) {
    return (
      <span className="font-mono text-xs text-muted-foreground">
        {details ? JSON.stringify(details) : "—"}
      </span>
    );
  }
  return (
    <div className="flex flex-col gap-1 text-xs">
      {avant && (
        <div className="rounded bg-red-50 px-2 py-1 font-mono text-red-800 dark:bg-red-950/40 dark:text-red-200">
          − {JSON.stringify(avant)}
        </div>
      )}
      {apres && (
        <div className="rounded bg-emerald-50 px-2 py-1 font-mono text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200">
          + {JSON.stringify(apres)}
        </div>
      )}
    </div>
  );
}

const AuditRow = React.memo(function AuditRow({
  row,
}: {
  row: NonNullable<ReturnType<typeof useAuditLogQuery>["data"]>[number];
}) {
  return (
    <TableRow>
      <TableCell className="whitespace-nowrap text-xs">
        {new Date(row.created_at).toLocaleString("fr-FR")}
      </TableCell>
      <TableCell className="text-xs">
        <div>{row.user_email ?? row.user_id ?? "—"}</div>
        {row.ip && <div className="text-muted-foreground">{row.ip}</div>}
        {row.user_agent && (
          <div className="max-w-[220px] truncate text-muted-foreground" title={row.user_agent}>
            {row.user_agent}
          </div>
        )}
      </TableCell>
      <TableCell>
        <Badge variant="outline">{row.action}</Badge>
      </TableCell>
      <TableCell className="text-xs">{row.role_code ?? "—"}</TableCell>
      <TableCell className="max-w-md">
        <DiffCell avant={row.avant} apres={row.apres} details={row.details} />
      </TableCell>
    </TableRow>
  );
});

export function AuditTab() {
  const q = useAuditLogQuery();
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [actionFilter, setActionFilter] = useState<string>("");

  useEffect(() => {
    const channel = supabase
      .channel("rbac-audit-log")
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "rbac_audit_log" },
        () => {
          qc.invalidateQueries({ queryKey: ["rbac", "audit"] });
        },
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [qc]);

  const rows = useMemo(() => {
    const s = search.trim().toLowerCase();
    return (q.data ?? []).filter((r) => {
      if (actionFilter && r.action !== actionFilter) return false;
      if (!s) return true;
      const hay = [
        r.user_email,
        r.role_code,
        r.action,
        JSON.stringify(r.details ?? {}),
        JSON.stringify(r.avant ?? {}),
        JSON.stringify(r.apres ?? {}),
      ]
        .join(" ")
        .toLowerCase();
      return hay.includes(s);
    });
  }, [q.data, search, actionFilter]);

  const actions = useMemo(
    () => Array.from(new Set((q.data ?? []).map((r) => r.action))).sort(),
    [q.data],
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle>Historique RBAC</CardTitle>
        <div className="mt-3 flex flex-wrap gap-2">
          <Input
            placeholder="Rechercher (utilisateur, rôle, permission…)"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="max-w-sm"
          />
          <select
            className="rounded-md border bg-background px-3 text-sm"
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
          >
            <option value="">Toutes les actions</option>
            {actions.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
          <span className="ml-auto self-center text-xs text-muted-foreground">
            {rows.length} entrée(s)
          </span>
        </div>
      </CardHeader>
      <CardContent>
        <ResponsiveTable>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Date</TableHead>
                <TableHead>Acteur / contexte</TableHead>
                <TableHead>Action</TableHead>
                <TableHead>Rôle</TableHead>
                <TableHead>Avant / Après</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((row) => (
                <AuditRow key={row.id} row={row} />
              ))}
            </TableBody>
          </Table>
        </ResponsiveTable>
      </CardContent>
    </Card>
  );
}
