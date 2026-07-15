// Shim to work around the reduced generated Database type after the schema reset.
// Re-exports the real supabase client cast to `SupabaseClient<any>` so calls to
// tables that are not yet present in the regenerated types.ts still type-check.
// The runtime behaviour is unchanged — the Data API still returns a proper
// error for missing tables.
import type { SupabaseClient } from "@supabase/supabase-js";
import { supabase as typedSupabase } from "./client";

export const supabase = typedSupabase as unknown as SupabaseClient<any, "public", any>;
