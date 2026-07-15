import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ACTION_LABEL, MODULES } from "@/lib/audit-helpers";

type Props = {
  search: string;
  setSearch: (v: string) => void;
  periodFilter: string;
  setPeriodFilter: (v: string) => void;
  userFilter: string;
  setUserFilter: (v: string) => void;
  moduleFilter: string;
  setModuleFilter: (v: string) => void;
  actionFilter: string;
  setActionFilter: (v: string) => void;
  users: string[];
  actions: string[];
};

export function AuditFilters({
  search,
  setSearch,
  periodFilter,
  setPeriodFilter,
  userFilter,
  setUserFilter,
  moduleFilter,
  setModuleFilter,
  actionFilter,
  setActionFilter,
  users,
  actions,
}: Props) {
  return (
    <div className="flex flex-wrap gap-3 rounded-md border bg-card p-4">
      <Input
        placeholder="Rechercher (utilisateur, module, référence)…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="w-72"
      />
      <Select value={periodFilter} onValueChange={setPeriodFilter}>
        <SelectTrigger className="w-40">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="1">Aujourd'hui</SelectItem>
          <SelectItem value="7">7 derniers jours</SelectItem>
          <SelectItem value="30">30 derniers jours</SelectItem>
          <SelectItem value="90">90 derniers jours</SelectItem>
          <SelectItem value="all">Tout l'historique</SelectItem>
        </SelectContent>
      </Select>
      <Select
        value={userFilter || "__all"}
        onValueChange={(v) => setUserFilter(v === "__all" ? "" : v)}
      >
        <SelectTrigger className="w-56">
          <SelectValue placeholder="Tous les utilisateurs" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="__all">Tous les utilisateurs</SelectItem>
          {users.map((u) => (
            <SelectItem key={u} value={u}>
              {u}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Select
        value={moduleFilter || "__all"}
        onValueChange={(v) => setModuleFilter(v === "__all" ? "" : v)}
      >
        <SelectTrigger className="w-56">
          <SelectValue placeholder="Tous les modules" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="__all">Tous les modules</SelectItem>
          {MODULES.map((m) => (
            <SelectItem key={m.value} value={m.value}>
              {m.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Select
        value={actionFilter || "__all"}
        onValueChange={(v) => setActionFilter(v === "__all" ? "" : v)}
      >
        <SelectTrigger className="w-56">
          <SelectValue placeholder="Toutes les actions" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="__all">Toutes les actions</SelectItem>
          {actions.map((a) => (
            <SelectItem key={a} value={a}>
              {ACTION_LABEL[a] ?? a}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
