import { supabase } from "@/integrations/supabase/client";

export type FNESettings = Record<string, string>;

export async function loadFNESettings(): Promise<FNESettings> {
  const { data, error } = await supabase
    .from("fne_settings")
    .select("cle, valeur")
    .not("cle", "like", "dgi_api_key%");
  if (error) throw error;
  const out: FNESettings = {};
  for (const r of data ?? []) out[r.cle as string] = (r.valeur ?? "") as string;
  return out;
}

export async function updateFNESetting(cle: string, valeur: string) {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("fne.modifier_parametres");
  const { data: existing } = await supabase
    .from("fne_settings")
    .select("setting_id")
    .eq("cle", cle)
    .maybeSingle();
  if (existing) {
    const { error } = await supabase.from("fne_settings").update({ valeur }).eq("cle", cle);
    if (error) throw error;
  } else {
    const { error } = await supabase.from("fne_settings").insert({ cle, valeur });
    if (error) throw error;
  }
}

export function isProductionReady(s: FNESettings): boolean {
  return Boolean(s.company_ncc && s.use_production === "true");
}
