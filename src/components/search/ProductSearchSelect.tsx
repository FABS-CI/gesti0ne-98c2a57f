import { SearchSelectBase } from "./SearchSelectBase";
import { listProduits, getProduit, type Produit } from "@/lib/produits-api";
import { ProductCoverThumb } from "@/components/produits/ProductCoverThumb";

export type ProductSearchSelectProps = {
  value: string | null | undefined;
  onChange: (id: string | null, produit: Produit | null) => void;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
  onlyActive?: boolean;
  loadingLabel?: string;
};

export function ProductSearchSelect({
  value,
  onChange,
  placeholder = "Rechercher un produit (titre, réf, ISBN, niveau)...",
  disabled,
  className,
  onlyActive = true,
  loadingLabel,
}: ProductSearchSelectProps) {
  return (
    <SearchSelectBase<Produit>
      value={value}
      onChange={onChange}
      queryKey="produit-search"
      placeholder={placeholder}
      disabled={disabled}
      className={className}
      emptyText="Aucun produit trouvé"
      minChars={0}
      wrapLabel
      loadingLabel={loadingLabel}
      search={async (term) => {
        const r = await listProduits({
          q: term,
          actif: onlyActive ? true : undefined,
          pageSize: 500,
        });
        return r.items;
      }}
      getById={(id) => getProduit(id)}
      getKey={(p) => p.produit_id}
      getLabel={(p) => `${p.titre}${p.reference ? " — " + p.reference : ""}`}
      renderItem={(p) => (
        <div className="flex items-start gap-2">
          <ProductCoverThumb produit={p} size="sm" />
          <div className="min-w-0 flex-1">
            <div className="font-medium whitespace-normal break-words leading-snug">
              {p.titre}
            </div>
            <div className="text-xs text-muted-foreground whitespace-normal break-words">
              {[p.reference, p.niveau, p.categorie, `Stock: ${p.stock ?? 0}`]
                .filter(Boolean)
                .join(" • ")}
            </div>
          </div>
        </div>
      )}
    />
  );
}
