export type AuditRow = {
  id: string;
  user_email: string | null;
  user_id: string | null;
  action: string;
  module: string | null;
  table_name: string;
  record_id: string | null;
  record_ref: string | null;
  occurred_at: string;
  old_values: unknown;
  new_values: unknown;
  changes: unknown;
  ip_address: string | null;
  user_agent: string | null;
  url: string | null;
  http_method: string | null;
  status: string | null;
  status_code?: number | null;
  duration_ms: number | null;
  error_message?: string | null;
  criticite?: "info" | "warning" | "critical" | null;
  session_id?: string | null;
  correlation_id?: string | null;
  city?: string | null;
  country?: string | null;
  country_code?: string | null;
  browser?: string | null;
  browser_version?: string | null;
  os?: string | null;
  device?: string | null;
  screen_resolution?: string | null;
  timezone?: string | null;
};

/** Couleur du badge selon le niveau de criticité. */
export const CRITICITE_STYLE: Record<
  string,
  { label: string; className: string }
> = {
  info: { label: "Info", className: "bg-blue-100 text-blue-800 dark:bg-blue-950/40 dark:text-blue-200" },
  warning: {
    label: "Avertissement",
    className: "bg-yellow-100 text-yellow-800 dark:bg-yellow-950/40 dark:text-yellow-200",
  },
  critical: {
    label: "Critique",
    className: "bg-red-100 text-red-800 dark:bg-red-950/40 dark:text-red-200",
  },
};

/** Couleur du badge résultat succès/erreur/annulé. */
export const STATUS_STYLE: Record<string, { label: string; className: string }> = {
  success: {
    label: "Succès",
    className: "bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200",
  },
  error: {
    label: "Erreur",
    className: "bg-red-100 text-red-800 dark:bg-red-950/40 dark:text-red-200",
  },
  cancelled: {
    label: "Annulé",
    className: "bg-slate-100 text-slate-800 dark:bg-slate-800/60 dark:text-slate-200",
  },
};

export const ACTION_LABEL: Record<string, string> = {
  INSERT: "Création",
  UPDATE: "Modification",
  DELETE: "Suppression",
  create_depot: "Création dépôt",
  update_depot: "Modification dépôt",
  delete_depot: "Suppression dépôt",
  ajuster_stock_depot: "Ajustement stock",
  create_approvisionnement: "Approvisionnement",
  create_inventaire_physique: "Création inventaire",
  valider_inventaire_physique: "Validation inventaire",
  regulariser_inventaire: "Régularisation inventaire",
  create_specimen: "Création spécimen",
  cancel_specimen: "Annulation spécimen",
  create_incident_stock: "Création incident",
  cancel_incident_stock: "Annulation incident",
};

export const ACTION_VARIANT = (action: string): "default" | "secondary" | "destructive" => {
  if (action.startsWith("delete") || action.startsWith("cancel") || action === "DELETE")
    return "destructive";
  if (action.startsWith("update") || action === "UPDATE") return "secondary";
  return "default";
};

export const MODULES = [
  { value: "depots", label: "Dépôts" },
  { value: "stocks_depots", label: "Stocks (ajustements)" },
  { value: "inventaires", label: "Inventaires" },
  { value: "achats", label: "Approvisionnements" },
  { value: "incidents", label: "Incidents" },
  { value: "specimens", label: "Spécimens" },
];
