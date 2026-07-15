import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { Check, ChevronsUpDown, Loader2, X } from "lucide-react";

import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { useDebouncedValue } from "@/hooks/use-debounced-value";

export type SearchSelectBaseProps<T> = {
  value: string | null | undefined;
  onChange: (id: string | null, item: T | null) => void;
  /** Fetch results matching the search term. */
  search: (term: string) => Promise<T[]>;
  /** Fetch a single item by id (to display the currently selected value). */
  getById: (id: string) => Promise<T | null>;
  getKey: (item: T) => string;
  getLabel: (item: T) => string;
  renderItem: (item: T) => ReactNode;
  /** React Query namespace, e.g. "client", "produit". */
  queryKey: string;
  placeholder?: string;
  emptyText?: string;
  disabled?: boolean;
  minChars?: number;
  className?: string;
  allowClear?: boolean;
  /** Autoriser le label sélectionné à passer sur plusieurs lignes (au lieu de tronquer). */
  wrapLabel?: boolean;
};

export function SearchSelectBase<T>({
  value,
  onChange,
  search,
  getById,
  getKey,
  getLabel,
  renderItem,
  queryKey,
  placeholder = "Rechercher…",
  emptyText = "Aucun résultat",
  disabled,
  minChars = 1,
  className,
  allowClear = true,
  wrapLabel = false,
}: SearchSelectBaseProps<T>) {
  const [open, setOpen] = useState(false);
  const [term, setTerm] = useState("");
  const debounced = useDebouncedValue(term, 250);
  const lastSelectedRef = useRef<T | null>(null);

  // Currently selected object (for display when collapsed)
  const selectedQuery = useQuery({
    queryKey: [queryKey, "by-id", value],
    queryFn: () => (value ? getById(value) : Promise.resolve(null)),
    enabled: !!value,
    staleTime: 5 * 60_000,
  });

  const selected = selectedQuery.data ?? lastSelectedRef.current;

  // Results query
  const resultsQuery = useQuery({
    queryKey: [queryKey, "search", debounced],
    queryFn: () => search(debounced),
    enabled: open && debounced.length >= minChars,
    staleTime: 30_000,
  });

  const results = useMemo(() => resultsQuery.data ?? [], [resultsQuery.data]);

  useEffect(() => {
    if (!open) setTerm("");
  }, [open]);

  const handleSelect = (item: T) => {
    lastSelectedRef.current = item;
    onChange(getKey(item), item);
    setOpen(false);
  };

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          role="combobox"
          aria-expanded={open}
          disabled={disabled}
          className={cn(
            "w-full justify-between font-normal",
            wrapLabel && "h-auto min-h-9 py-1 items-start",
            !selected && "text-muted-foreground",
            className,
          )}
        >
          <span
            className={cn(
              "text-left",
              wrapLabel ? "whitespace-normal break-words leading-snug" : "truncate",
            )}
          >
            {selected ? getLabel(selected) : placeholder}
          </span>
          <span className="flex items-center gap-1">
            {allowClear && selected && !disabled && (
              <span
                role="button"
                tabIndex={-1}
                onClick={(e) => {
                  e.stopPropagation();
                  lastSelectedRef.current = null;
                  onChange(null, null);
                }}
                className="rounded p-0.5 hover:bg-muted"
              >
                <X className="h-3.5 w-3.5" />
              </span>
            )}
            <ChevronsUpDown className="h-4 w-4 opacity-50" />
          </span>
        </Button>
      </PopoverTrigger>
      <PopoverContent
        className="w-[var(--radix-popover-trigger-width)] min-w-[320px] p-0"
        align="start"
      >
        <Command shouldFilter={false}>
          <CommandInput placeholder={placeholder} value={term} onValueChange={setTerm} />
          <CommandList>
            {minChars > 0 && debounced.length < minChars ? (
              <div className="p-3 text-sm text-muted-foreground">
                Tapez au moins {minChars} caractère{minChars > 1 ? "s" : ""} pour rechercher…
              </div>
            ) : resultsQuery.isLoading ? (
              <div className="flex items-center gap-2 p-3 text-sm text-muted-foreground">
                <Loader2 className="h-4 w-4 animate-spin" />
                Recherche…
              </div>
            ) : results.length === 0 ? (
              <CommandEmpty>{emptyText}</CommandEmpty>
            ) : (
              <CommandGroup>
                {results.map((item) => {
                  const id = getKey(item);
                  const isSelected = id === value;
                  return (
                    <CommandItem
                      key={id}
                      value={id}
                      onSelect={() => handleSelect(item)}
                      className="flex items-start gap-2"
                    >
                      <Check
                        className={cn(
                          "mt-0.5 h-4 w-4 shrink-0",
                          isSelected ? "opacity-100" : "opacity-0",
                        )}
                      />
                      <div className="flex-1 min-w-0">{renderItem(item)}</div>
                    </CommandItem>
                  );
                })}
              </CommandGroup>
            )}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}
