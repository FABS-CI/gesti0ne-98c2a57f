import { supabase } from "@/integrations/supabase/client";

export type Parametre = {
  parametre_id: string;
  cle: string;
  valeur: string | null;
  description: string | null;
};

export async function getParametre(cle: string): Promise<string | null> {
  const { data, error } = await supabase
    .from("parametres")
    .select("valeur")
    .eq("cle", cle)
    .maybeSingle();
  if (error) throw error;
  return (data?.valeur ?? null) as string | null;
}

export async function setParametre(cle: string, valeur: string | null) {
  const { error } = await supabase
    .from("parametres")
    .upsert({ cle, valeur }, { onConflict: "cle" });
  if (error) throw error;
}

/** UUID du dépôt proposé par défaut (ventes / commandes / approvisionnements). */
export async function getDepotDefautId(): Promise<string | null> {
  return getParametre("depot_defaut_id");
}

export async function setDepotDefautId(depotId: string | null) {
  return setParametre("depot_defaut_id", depotId);
}
