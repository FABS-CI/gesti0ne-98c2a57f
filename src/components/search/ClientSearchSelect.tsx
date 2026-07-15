import { SearchSelectBase } from "./SearchSelectBase";
import { listClients, getClient, type Client } from "@/lib/clients-api";

export type ClientSearchSelectProps = {
  value: string | null | undefined;
  onChange: (id: string | null, client: Client | null) => void;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
  /** Restreindre aux clients actifs (par défaut: true). */
  onlyActive?: boolean;
};

export function ClientSearchSelect({
  value,
  onChange,
  placeholder = "Rechercher un client (nom, représentant, ville, tél)…",
  disabled,
  className,
  onlyActive = true,
}: ClientSearchSelectProps) {
  return (
    <SearchSelectBase<Client>
      value={value}
      onChange={onChange}
      queryKey="client-search"
      placeholder={placeholder}
      disabled={disabled}
      className={className}
      emptyText="Aucun client trouvé"
      search={async (term) => {
        const r = await listClients({
          q: term,
          actif: onlyActive ? true : undefined,
          pageSize: 20,
        });
        return r.items;
      }}
      getById={(id) => getClient(id)}
      getKey={(c) => c.client_id}
      getLabel={(c) => `${c.nom}${c.ville ? " — " + c.ville : ""}`}
      renderItem={(c) => (
        <div>
          <div className="font-medium truncate">{c.nom}</div>
          <div className="text-xs text-muted-foreground truncate">
            {[c.representant, c.ville, c.telephone].filter(Boolean).join(" • ") || "—"}
          </div>
        </div>
      )}
    />
  );
}
