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
  group: "Clients" | "Représentants" | "Produits" | "Factures" | "Bons de livraison";
  label: string;
  sub?: string;
  to: string;
  params?: Record<string, string>;
  icon: typeof Users;
};

async function search(q: string): Promise<Hit[]> {
  const term = q.trim();
  if (term.length < 3) return [];
  const like = `%${term}%`;

  // Coalesce clients + représentants in a single query
  const [clientsAll, produits, factures, bls] = await Promise.all([
    supabase
      .from("clients")
      .select("client_id, nom, ville, representant")
      .or(`nom.ilike.${like},representant.ilike.${like}`)
      .limit(12),
    supabase
      .from("produits")
      .select("produit_id, titre, reference")
      .or(`titre.ilike.${like},reference.ilike.${like},isbn.ilike.${like}`)
      .order("niveau_ordre", { ascending: true })
      .order("titre", { ascending: true })
      .limit(8),
    supabase
      .from("factures")
      .select("facture_id, reference, client_nom, montant_total")
      .or(`reference.ilike.${like},client_nom.ilike.${like}`)
      .limit(8),
    supabase
      .from("bons_livraison")
      .select("bl_id, reference, signataire, transporteur")
      .or(`reference.ilike.${like},signataire.ilike.${like},transporteur.ilike.${like}`)
      .limit(8),
  ]);

  const hits: Hit[] = [];
  const termLower = term.toLowerCase();

  for (const c of clientsAll.data ?? []) {
    const nomMatch = c.nom?.toLowerCase().includes(termLower);
    if (nomMatch) {
      hits.push({
        id: `c-${c.client_id}`,
        group: "Clients",
        label: c.nom,
        sub: [c.ville, c.representant].filter(Boolean).join(" · "),
        to: "/clients/$clientId",
        params: { clientId: c.client_id },
        icon: Users,
      });
    }
    const repMatch = c.representant?.toLowerCase().includes(termLower);
    if (repMatch && !nomMatch) {
      hits.push({
        id: `r-${c.client_id}`,
        group: "Représentants",
        label: c.representant ?? "",
        sub: `Client : ${c.nom}`,
        to: "/clients/$clientId",
        params: { clientId: c.client_id },
        icon: UserCircle,
      });
    }
  }

  for (const p of produits.data ?? [])
    hits.push({
      id: `p-${p.produit_id}`,
      group: "Produits",
      label: p.titre,
      sub: p.reference,
      to: "/produits/$produitId",
      params: { produitId: p.produit_id },
      icon: Package,
    });

  for (const f of factures.data ?? [])
    hits.push({
      id: `f-${f.facture_id}`,
      group: "Factures",
      label: f.reference,
      sub: [f.client_nom, f.montant_total ? `${f.montant_total} F` : null]
        .filter(Boolean)
        .join(" · "),
      to: "/factures/$factureId",
      params: { factureId: f.facture_id },
      icon: FileText,
    });

  for (const b of bls.data ?? [])
    hits.push({
      id: `b-${b.bl_id}`,
      group: "Bons de livraison",
      label: b.reference,
      sub: [b.signataire, b.transporteur].filter(Boolean).join(" · "),
      to: "/bons-livraison",
      icon: Truck,
    });

  return hits;
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
    enabled: debounced.trim().length >= 3,
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
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    navigate({ to: h.to as any, params: h.params as any });
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="hidden h-10 w-full max-w-md items-center gap-2 rounded-lg border border-input bg-muted/40 px-3 text-sm text-muted-foreground transition-colors hover:bg-muted sm:flex"
      >
        <Search className="h-4 w-4" />
        <span className="flex-1 text-left">Rechercher (clients, produits, factures…)</span>
        <kbd className="rounded border bg-background px-1.5 py-0.5 text-[10px] font-mono">
          Ctrl + K
        </kbd>
      </button>

      <CommandDialog open={open} onOpenChange={setOpen}>
        <CommandInput
          value={value}
          onValueChange={setValue}
          placeholder="Rechercher un client, représentant, produit, facture, BL…"
        />
        <CommandList>
          {debounced.trim().length < 3 ? (
            <CommandEmpty>Tapez au moins 3 caractères…</CommandEmpty>
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
