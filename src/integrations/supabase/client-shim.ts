// Shim to work around the reduced generated Database type after the schema reset.
// Re-exports the real supabase client cast to `any` so calls to tables/functions
// that are not yet present in the regenerated types.ts still type-check.
// Runtime behaviour is unchanged.
import { supabase as typedSupabase } from "./client";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const supabase: any = typedSupabase;
