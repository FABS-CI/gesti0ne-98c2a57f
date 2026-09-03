import { Card, CardContent } from "@/components/ui/card";
import { formatFCFA } from "@/lib/format";

import {
  Activity,
  Users,
  Calendar,
  CalendarDays,
  CalendarRange,
  LogIn,
  LogOut,
  ShieldAlert,
  ShieldX,
  Plus,
  Pencil,
  Trash2,
  Printer,
  FileDown,
  FileSpreadsheet,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Bell,
  Circle,
} from "lucide-react";
import type { AuditKpi } from "@/hooks/use-audit-events";

type Tile = {
  key: keyof AuditKpi;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  color: string;
};

const TILES: Tile[] = [
  { key: "today", label: "Aujourd'hui", icon: Calendar, color: "text-[#F97316]" },
  { key: "week", label: "Cette semaine", icon: CalendarDays, color: "text-blue-500" },
  { key: "month", label: "Ce mois", icon: CalendarRange, color: "text-indigo-500" },
  { key: "active_users_today", label: "Utilisateurs actifs", icon: Users, color: "text-emerald-500" },
  { key: "connected_now", label: "Connectés (15 min)", icon: Circle, color: "text-emerald-500" },
  { key: "logins", label: "Connexions", icon: LogIn, color: "text-emerald-600" },
  { key: "logouts", label: "Déconnexions", icon: LogOut, color: "text-slate-500" },
  { key: "login_failed", label: "Échecs connexion", icon: ShieldX, color: "text-red-500" },
  { key: "creations", label: "Créations", icon: Plus, color: "text-emerald-500" },
  { key: "modifications", label: "Modifications", icon: Pencil, color: "text-amber-500" },
  { key: "suppressions", label: "Suppressions", icon: Trash2, color: "text-red-500" },
  { key: "impressions", label: "Impressions", icon: Printer, color: "text-slate-500" },
  { key: "exports_pdf", label: "Exports PDF", icon: FileDown, color: "text-rose-500" },
  { key: "exports_excel", label: "Exports Excel/CSV", icon: FileSpreadsheet, color: "text-green-600" },
  { key: "validations", label: "Validations", icon: CheckCircle2, color: "text-emerald-600" },
  { key: "annulations", label: "Annulations", icon: XCircle, color: "text-orange-500" },
  { key: "system_errors", label: "Erreurs système", icon: AlertTriangle, color: "text-red-600" },
  { key: "security_alerts", label: "Alertes sécurité", icon: Bell, color: "text-red-600" },
];

type Props = { kpi?: AuditKpi; totalEvents?: number };

export function AuditStats({ kpi, totalEvents }: Props) {
  const v = (k: keyof AuditKpi) => Number(kpi?.[k] ?? 0);
  return (
    <div className="space-y-3">
      {typeof totalEvents === "number" && (
        <Card>
          <CardContent className="flex items-center gap-3 p-4">
            <Activity className="h-6 w-6 text-[#F97316]" />
            <div className="text-sm text-muted-foreground">Événements sur la période</div>
            <div className="ml-auto text-2xl font-bold tabular-nums">
              {formatFCFA(totalEvents, false)}
            </div>
          </CardContent>
        </Card>
      )}
      <div className="grid gap-2 grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6">
        {TILES.map(({ key, label, icon: Icon, color }) => (
          <Card key={key}>
            <CardContent className="flex items-center gap-2 p-3">
              <Icon className={`h-5 w-5 shrink-0 ${color}`} />
              <div className="min-w-0">
                <div className="text-lg font-bold tabular-nums leading-tight">
                  {formatFCFA(v(key), false)}
                </div>
                <div className="truncate text-[11px] text-muted-foreground">{label}</div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
