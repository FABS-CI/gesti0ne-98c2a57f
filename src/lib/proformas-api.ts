import { supabase } from "@/integrations/supabase/client";

/**
 * Suppression définitive d'une proforma (Super Administrateur uniquement).
 * Le contrôle et la cascade (proforma_lignes) sont effectués côté RPC.
 */
export async function deleteProformaDefinitif(proformaId: string, motif?: string) {
  const { assertPermission } = await import("@/lib/rbac-api");
  await assertPermission("proformas.supprimer");
  const { error } = await supabase.rpc("supprimer_proforma_definitif", {
    _proforma_id: proformaId,
    _motif: motif ?? undefined,
  });
  if (error) throw new Error(error.message);
}
