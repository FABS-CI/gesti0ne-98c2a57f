// Shim to work around the reduced generated Database type after the schema reset.
// Wraps the real auth middleware so `context.supabase` is `any` — RPC calls and
// table reads against tables missing from types.ts still type-check.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
import { requireSupabaseAuth as realMiddleware } from "./auth-middleware";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const requireSupabaseAuth: any = realMiddleware;
