import { supabase } from "@/integrations/supabase/client";
import { audit } from "@/lib/audit-client";
import type { Database } from "@/integrations/supabase/types";

type RpcName = keyof Database["public"]["Functions"];

/**
 * Appelle une RPC Supabase avec chrono + journalisation automatique des échecs
 * dans audit_events (visible via /admin/rpc-errors pour super_admin).
 *
 * Usage :
 *   const { data } = await callRpc("creer_commande", { _payload: payload });
 */
export async function callRpc<K extends RpcName>(
  fn: K,
  args?: Database["public"]["Functions"][K]["Args"],
  opts?: { module?: string; recordId?: string; recordRef?: string },
): Promise<{
  data: Database["public"]["Functions"][K]["Returns"] | null;
  error: { message: string; code?: string; details?: string } | null;
}> {
  const started = performance.now();
  const { data, error } = await (
    supabase.rpc as unknown as (
      name: string,
      args?: Record<string, unknown>,
    ) => Promise<{
      data: unknown;
      error: { message: string; details?: string; code?: string } | null;
    }>
  )(fn, (args as Record<string, unknown> | undefined) ?? {});
  const duration = Math.round(performance.now() - started);

  if (error) {
    audit({
      action: "VALIDATION",
      module: opts?.module ?? "rpc",
      table_name: String(fn),
      record_id: opts?.recordId,
      record_ref: opts?.recordRef,
      status: "error",
      error_message: [error.message, error.details].filter(Boolean).join(" — ").slice(0, 1000),
      duration_ms: duration,
      metadata: { rpc: String(fn), code: (error as { code?: string }).code },
    });
    return {
      data: null,
      error: {
        message: error.message,
        code: (error as { code?: string }).code,
        details: (error as { details?: string }).details,
      },
    };
  }

  return { data: data as Database["public"]["Functions"][K]["Returns"], error: null };
}
