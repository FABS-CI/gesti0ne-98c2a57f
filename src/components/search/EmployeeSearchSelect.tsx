import { SearchSelectBase } from "./SearchSelectBase";
import { supabase } from "@/integrations/supabase/client";
import { listEmployes, type Employe } from "@/lib/rh-api";

async function getEmployeById(id: string): Promise<Employe | null> {
  const { data, error } = await supabase
    .from("employes")
    .select("*")
    .eq("employe_id", id)
    .maybeSingle();
  if (error) throw error;
  return (data as Employe | null) ?? null;
}

export type EmployeeSearchSelectProps = {
  value: string | null | undefined;
  onChange: (id: string | null, employe: Employe | null) => void;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
};

export function EmployeeSearchSelect({
  value,
  onChange,
  placeholder = "Rechercher un employé (nom, matricule, poste)…",
  disabled,
  className,
}: EmployeeSearchSelectProps) {
  return (
    <SearchSelectBase<Employe>
      value={value}
      onChange={onChange}
      queryKey="employe-search"
      placeholder={placeholder}
      disabled={disabled}
      className={className}
      emptyText="Aucun employé trouvé"
      search={async (term) => {
        const items = await listEmployes(term);
        return items.slice(0, 20);
      }}
      getById={getEmployeById}
      getKey={(e) => e.employe_id}
      getLabel={(e) => `${e.nom_complet}${e.matricule ? " — " + e.matricule : ""}`}
      renderItem={(e) => (
        <div>
          <div className="font-medium truncate">{e.nom_complet}</div>
          <div className="text-xs text-muted-foreground truncate">
            {[e.matricule, e.poste, e.departement].filter(Boolean).join(" • ") || "—"}
          </div>
        </div>
      )}
    />
  );
}
