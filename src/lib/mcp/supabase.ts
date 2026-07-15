/**
 * Lazy-loader for the admin Supabase client, used inside MCP tool handlers.
 * MCP entry + tool files are import-evaluated at build time — never read
 * env or import server-only modules at top level.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/integrations/supabase/types";

export async function getAdmin(): Promise<SupabaseClient<Database>> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  return supabaseAdmin as SupabaseClient<Database>;
}
