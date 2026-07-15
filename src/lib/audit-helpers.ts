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
  duration_ms: number | null;
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
