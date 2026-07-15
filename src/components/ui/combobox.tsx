import { useMemo, useState } from "react";
import { Check, ChevronsUpDown, X } from "lucide-react";
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
import { filterByTerm } from "@/lib/ci-locations";

export type ComboboxProps = {
  value: string | null | undefined;
  onChange: (val: string | null) => void;
  options: string[];
  placeholder?: string;
  emptyText?: string;
  disabled?: boolean;
  allowClear?: boolean;
  className?: string;
  /** Autorise la saisie libre d'une valeur non listée. */
  allowCustom?: boolean;
};

/** Combobox simple avec recherche intelligente (insensible aux accents / casse). */
export function Combobox({
  value,
  onChange,
  options,
  placeholder = "Sélectionner…",
  emptyText = "Aucun résultat",
  disabled,
  allowClear = true,
  className,
  allowCustom = true,
}: ComboboxProps) {
  const [open, setOpen] = useState(false);
  const [term, setTerm] = useState("");

  const filtered = useMemo(() => filterByTerm(options, term), [options, term]);
  const showCustom =
    allowCustom &&
    term.trim().length > 0 &&
    !options.some((o) => o.toLowerCase() === term.trim().toLowerCase());

  return (
    <Popover
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) setTerm("");
      }}
    >
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          role="combobox"
          aria-expanded={open}
          disabled={disabled}
          className={cn(
            "w-full justify-between font-normal",
            !value && "text-muted-foreground",
            className,
          )}
        >
          <span className="truncate text-left">{value || placeholder}</span>
          <span className="flex items-center gap-1">
            {allowClear && value && !disabled && (
              <span
                role="button"
                tabIndex={-1}
                onClick={(e) => {
                  e.stopPropagation();
                  onChange(null);
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
        className="w-[var(--radix-popover-trigger-width)] min-w-[260px] p-0"
        align="start"
      >
        <Command shouldFilter={false}>
          <CommandInput placeholder="Rechercher…" value={term} onValueChange={setTerm} />
          <CommandList>
            {filtered.length === 0 && !showCustom ? (
              <CommandEmpty>{emptyText}</CommandEmpty>
            ) : (
              <CommandGroup>
                {filtered.map((opt) => (
                  <CommandItem
                    key={opt}
                    value={opt}
                    onSelect={() => {
                      onChange(opt);
                      setOpen(false);
                    }}
                  >
                    <Check
                      className={cn("mr-2 h-4 w-4", value === opt ? "opacity-100" : "opacity-0")}
                    />
                    {opt}
                  </CommandItem>
                ))}
                {showCustom && (
                  <CommandItem
                    key="__custom__"
                    value={term}
                    onSelect={() => {
                      onChange(term.trim());
                      setOpen(false);
                    }}
                  >
                    <Check className="mr-2 h-4 w-4 opacity-0" />
                    Utiliser « {term.trim()} »
                  </CommandItem>
                )}
              </CommandGroup>
            )}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}
