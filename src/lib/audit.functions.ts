import { createServerFn } from "@tanstack/react-start";
import { getRequestHeader, getRequestIP } from "@tanstack/react-start/server";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const AuditActionSchema = z.enum([
  "INSERT",
  "UPDATE",
  "DELETE",
  "LOGIN",
  "LOGIN_FAILED",
  "LOGOUT",
  "EXPORT",
  "IMPORT",
  "PRINT",
  "DOWNLOAD",
  "UPLOAD",
  "VALIDATION",
  "APPROBATION",
  "ANNULATION",
  "CONSULTATION",
]);

const InputSchema = z.object({
  action: AuditActionSchema,
  module: z.string().max(80).optional(),
  table_name: z.string().max(80).optional(),
  record_id: z.string().max(80).optional(),
  record_ref: z.string().max(120).optional(),
  url: z.string().max(2048).optional(),
  http_method: z.string().max(10).optional(),
  status: z.enum(["success", "error", "cancelled"]).default("success"),
  error_message: z.string().max(1000).optional(),
  duration_ms: z.number().int().nonnegative().max(600_000).optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

export type AuditEventInput = z.input<typeof InputSchema>;

/**
 * Écrit un événement dans le journal d'audit (audit_events).
 * IP et user-agent sont capturés automatiquement côté serveur.
 */
export const logAuditEvent = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => InputSchema.parse(raw))
  .handler(async ({ data, context }) => {
    const ua = getRequestHeader("user-agent") ?? undefined;
    let ip: string | undefined = undefined;
    try {
      ip = getRequestIP({ xForwardedFor: true }) ?? undefined;
    } catch {
      ip = undefined;
    }

    const { data: id, error } = await context.supabase.rpc("log_audit_event", {
      p_action: data.action,
      p_module: data.module,
      p_table_name: data.table_name,
      p_record_id: data.record_id,
      p_record_ref: data.record_ref,
      p_url: data.url,
      p_http_method: data.http_method,
      p_status: data.status ?? "success",
      p_error_message: data.error_message,
      p_duration_ms: data.duration_ms,
      p_metadata: data.metadata as never,
      p_ip: ip,
      p_user_agent: ua,
    });

    if (error) throw new Error(`audit: ${error.message}`);
    return { id };
  });
