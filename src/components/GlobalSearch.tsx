import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Users, Package, FileText, Truck, UserCircle, Search, Loader2 } from "lucide-react";

import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from "@/components/ui/command";
import { supabase } from "@/integrations/supabase/client";
import { useDebouncedValue } from "@/hooks/use-debounced-value";

type Hit = {
  id: string;
  group: string;
  label: string;
  sub?: string;
  to: string;
  params?: Record<string, string>;
  icon: typeof Users;
};

async function search(q: string): Promise<Hit[]> {
  const term = q.trim();
  if (term.length < 2) return [];

  const { data, error } = await supabase.rpc("global_search", { _q: term });
  if (error) {
    console.error("GlobalSearch error:", error);
    return [];
  }

  return (data as any[]).map((h) => ({
    ...h,
    icon:
      h.group === "Clients"
        ? Users
        : h.group === "Représentants" || h.group === "Utilisateurs"
        ? UserCircle
        : h.group === "Produits"
        ? Package
        : h.group === "Bons de livraison" || h.group === "Cartons"
        ? Truck
        : FileText,
  }));
}

export function GlobalSearch() {
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState("");
  const debounced = useDebouncedValue(value, 350);
  const navigate = useNavigate();

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.key === "k" || e.key === "K") && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

  const { data: hits = [], isFetching } = useQuery({
    queryKey: ["global-search", debounced],
    queryFn: () => search(debounced),
    enabled: debounced.trim().length >= 2,
    staleTime: 60_000,
    gcTime: 5 * 60_000,
  });

  const grouped = useMemo(() => {
    const map = new Map<string, Hit[]>();
    for (const h of hits) {
      const arr = map.get(h.group) ?? [];
      arr.push(h);
      map.set(h.group, arr);
    }
    return Array.from(map.entries());
  }, [hits]);

  function go(h: Hit) {
    setOpen(false);
    setValue("");
    // We use @ts-ignore for dynamic routing parameters that TanStack Router cannot statically verify from the search index
    // @ts-ignore
    navigate({ to: h.to, params: h.params });
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex h-10 w-full max-w-xl items-center gap-2 rounded-xl border border-input bg-muted/60 px-3 text-sm text-muted-foreground shadow-sm transition-all hover:bg-muted hover:ring-2 hover:ring-primary/20 sm:h-11 sm:gap-3 sm:px-4"
      >
        <Search className="h-4 w-4 text-primary shrink-0 sm:h-5 sm:w-5" />
        <span className="flex-1 text-left font-medium truncate">Rechercher...</span>
        <kbd className="hidden rounded border bg-background px-2 py-1 text-[10px] font-mono font-bold shadow-xs sm:inline-block">
          Ctrl + K
        </kbd>
      </button>

      <CommandDialog open={open} onOpenChange={setOpen}>
        <CommandInput
          value={value}
          onValueChange={setValue}
          placeholder="Rechercher : Client, CMD-2026..., FAC-2026..., téléphone, ville..."
        />
        <CommandList>
          {debounced.trim().length < 2 ? (
            <CommandEmpty>Tapez au moins 2 caractères…</CommandEmpty>
          ) : isFetching && hits.length === 0 ? (
            <div className="flex items-center justify-center gap-2 py-6 text-sm text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" /> Recherche…
            </div>
          ) : hits.length === 0 ? (
            <CommandEmpty>Aucun résultat</CommandEmpty>
          ) : (
            grouped.map(([group, items], i) => (
              <div key={group}>
                {i > 0 && <CommandSeparator />}
                <CommandGroup heading={group}>
                  {items.map((h) => {
                    const Icon = h.icon;
                    return (
                      <CommandItem
                        key={h.id}
                        value={`${h.group} ${h.label} ${h.sub ?? ""}`}
                        onSelect={() => go(h)}
                        className="gap-2"
                      >
                        <Icon className="h-4 w-4 text-muted-foreground" />
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-sm">{h.label}</div>
                          {h.sub && (
                            <div className="truncate text-xs text-muted-foreground">{h.sub}</div>
                          )}
                        </div>
                      </CommandItem>
                    );
                  })}
                </CommandGroup>
              </div>
            ))
          )}
        </CommandList>
      </CommandDialog>
    </>
  );
}
