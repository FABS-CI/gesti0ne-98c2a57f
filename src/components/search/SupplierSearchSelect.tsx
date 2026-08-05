import { SearchSelectBase } from "./SearchSelectBase";
import { listFournisseurs, getFournisseur, type Fournisseur } from "@/lib/fournisseurs-api";

export type SupplierSearchSelectProps = {
  value: string | null | undefined;
  onChange: (id: string | null, fournisseur: Fournisseur | null) => void;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
};

export function SupplierSearchSelect({
  value,
  onChange,
  placeholder = "Rechercher un fournisseur (nom, ville, représentant)…",
  disabled,
  className,
}: SupplierSearchSelectProps) {
  return (
    <SearchSelectBase<Fournisseur>
      value={value}
      onChange={onChange}
      queryKey="fournisseur-search"
      placeholder={placeholder}
      disabled={disabled}
      className={className}
      emptyText="Aucun fournisseur trouvé"
      minChars={0}
      search={async (term) => {
        const items = await listFournisseurs(term);
        return items.slice(0, 20);
      }}
      getById={(id) => getFournisseur(id)}
      getKey={(f) => f.fournisseur_id}
      getLabel={(f) => `${f.raison_sociale}${f.ville ? " — " + f.ville : ""}`}
      renderItem={(f) => (
        <div>
          <div className="font-medium truncate">{f.raison_sociale}</div>
          <div className="text-xs text-muted-foreground truncate">
            {[f.representant, f.ville, f.telephone].filter(Boolean).join(" • ") || "—"}
          </div>
        </div>
      )}
    />
  );
}
