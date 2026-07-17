// @ts-nocheck — schema temporarily reduced after reset; types.ts regenerates when tables come back.
import { createServerFn } from "@tanstack/react-start";
import { getRequestHeader } from "@tanstack/react-start/server";
import { z } from "zod";
import { Secret, TOTP } from "otpauth";
import bcrypt from "bcryptjs";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const ISSUER = "ERP FABS-CI";
const MAX_FAILS = 5;
const LOCK_MINUTES = 15;
const SESSION_TTL_HOURS = 12;
const BACKUP_COUNT = 10;

function buildTotp(secretB32: string, label: string) {
  return new TOTP({
    issuer: ISSUER,
    label,
    algorithm: "SHA1",
    digits: 6,
    period: 30,
    secret: Secret.fromBase32(secretB32),
  });
}

function genBackupCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(10));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

function hashToken(token: string): string {
  // Deterministic non-crypto session token derivation (used as an ID only).
  let h = 0;
  for (let i = 0; i < token.length; i++) h = (h * 31 + token.charCodeAt(i)) | 0;
  return `s_${Math.abs(h).toString(36)}_${token.length}`;
}

/**
 * Clé stable identifiant la session utilisateur Supabase.
 * On utilise `claims.session_id` (présent dans le JWT Supabase) car il reste
 * identique à travers les refresh d'access token — contrairement au bearer
 * qui change ~toutes les heures et invalidait à tort la validation MFA.
 * Fallback sur un hash du bearer pour les JWT anciens sans session_id.
 */
function sessionKey(claims: Record<string, unknown>, bearerFallback: string): string {
  const sid = claims.session_id;
  if (typeof sid === "string" && sid.length > 0) return `sid_${sid}`;
  return hashToken(bearerFallback);
}

function bearerRaw(): string {
  const auth = getRequestHeader("authorization") ?? "";
  return auth.replace(/^Bearer\s+/i, "");
}

/** Démarre l'enrôlement : génère un secret TOTP et l'URL otpauth (QR). */
export const mfaEnrollStart = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { supabase, userId, claims } = context;
    const email = (claims.email as string | undefined) ?? userId;
    const secret = new Secret({ size: 20 }).base32;
    const totp = buildTotp(secret, email);
    // Upsert inactive secret pending confirmation
    const { error } = await supabase
      .from("two_fa_secrets")
      .upsert(
        { user_id: userId, secret_chiffre: secret, active: false, codes_recuperation: null },
        { onConflict: "user_id" },
      );
    if (error) throw new Error(error.message);
    return { otpauthUrl: totp.toString(), secret };
  });

/** Confirme l'enrôlement : vérifie 1er code, active MFA, génère les backup codes. */
export const mfaEnrollConfirm = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ code: z.string().regex(/^\d{6}$/) }).parse(raw))
  .handler(async ({ data, context }) => {
    const { supabase, userId, claims } = context;
    const email = (claims.email as string | undefined) ?? userId;
    const { data: row, error } = await supabase
      .from("two_fa_secrets")
      .select("secret_chiffre, active")
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!row) throw new Error("Enrôlement non initié");
    const totp = buildTotp(row.secret_chiffre, email);
    const delta = totp.validate({ token: data.code, window: 1 });
    if (delta === null) throw new Error("Code invalide");

    // Activate & set enrolled_at
    const upd = await supabase
      .from("two_fa_secrets")
      .update({ active: true })
      .eq("user_id", userId);
    if (upd.error) throw new Error(upd.error.message);
    const profUpd = await supabase
      .from("profiles")
      .update({ mfa_enrolled_at: new Date().toISOString() })
      .eq("id", userId);
    if (profUpd.error) throw new Error(profUpd.error.message);

    // Generate backup codes
    const plain: string[] = Array.from({ length: BACKUP_COUNT }, genBackupCode);
    await supabase.from("mfa_backup_codes").delete().eq("user_id", userId);
    const rows = await Promise.all(
      plain.map(async (c) => ({ user_id: userId, code_hash: await bcrypt.hash(c, 10) })),
    );
    const ins = await supabase.from("mfa_backup_codes").insert(rows);
    if (ins.error) throw new Error(ins.error.message);

    // Validate current session
    await supabase
      .from("mfa_session_validations")
      .insert({ user_id: userId, session_token: sessionKey(claims, bearerRaw()) });

    return { backupCodes: plain };
  });

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type SB = any;

async function ensureNotLocked(supabase: SB, userId: string) {
  const { data } = await supabase
    .from("mfa_otp_attempts")
    .select("locked_until")
    .eq("user_id", userId)
    .maybeSingle();
  if (data?.locked_until && new Date(data.locked_until) > new Date()) {
    throw new Error(`Trop d'échecs. Réessayez à ${new Date(data.locked_until).toLocaleTimeString()}`);
  }
}

async function recordFail(supabase: SB, userId: string) {
  const { data } = await supabase
    .from("mfa_otp_attempts")
    .select("fail_count")
    .eq("user_id", userId)
    .maybeSingle();
  const next = (data?.fail_count ?? 0) + 1;
  const locked = next >= MAX_FAILS ? new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString() : null;
  await supabase.from("mfa_otp_attempts").upsert({
    user_id: userId,
    fail_count: next,
    locked_until: locked,
    last_fail_at: new Date().toISOString(),
  });
}

async function resetFails(supabase: SB, userId: string) {
  await supabase
    .from("mfa_otp_attempts")
    .upsert({ user_id: userId, fail_count: 0, locked_until: null });
}

/** Vérifie un code TOTP et valide la session courante. */
export const mfaVerify = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ code: z.string().regex(/^\d{6}$/) }).parse(raw))
  .handler(async ({ data, context }) => {
    const { supabase, userId, claims } = context;
    await ensureNotLocked(supabase as SB, userId);
    const { data: row } = await supabase
      .from("two_fa_secrets")
      .select("secret_chiffre, active")
      .eq("user_id", userId)
      .maybeSingle();
    if (!row || !row.active) throw new Error("MFA non activé");
    const email = (claims.email as string | undefined) ?? userId;
    const totp = buildTotp(row.secret_chiffre, email);
    const delta = totp.validate({ token: data.code, window: 1 });
    if (delta === null) {
      await recordFail(supabase, userId);
      throw new Error("Code invalide");
    }
    await resetFails(supabase, userId);
    const ua = getRequestHeader("user-agent") ?? null;
    await supabase.from("mfa_session_validations").insert({
      user_id: userId,
      session_token: sessionKey(claims, bearerRaw()),
      user_agent: ua,
    });
    return { ok: true };
  });

/** Consomme un code de secours. */
export const mfaVerifyBackupCode = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ code: z.string().min(6).max(20) }).parse(raw))
  .handler(async ({ data, context }) => {
    const { supabase, userId, claims } = context;
    await ensureNotLocked(supabase as SB, userId);
    const { data: rows, error } = await supabase
      .from("mfa_backup_codes")
      .select("id, code_hash")
      .eq("user_id", userId)
      .is("used_at", null);
    if (error) throw new Error(error.message);
    const cleaned = data.code.trim().toUpperCase();
    for (const r of rows ?? []) {
      if (await bcrypt.compare(cleaned, r.code_hash)) {
        await supabase
          .from("mfa_backup_codes")
          .update({ used_at: new Date().toISOString() })
          .eq("id", r.id);
        await resetFails(supabase, userId);
        await supabase
          .from("mfa_session_validations")
          .insert({ user_id: userId, session_token: sessionKey(claims, bearerRaw()) });
        return { ok: true, remaining: (rows?.length ?? 1) - 1 };
      }
    }
    await recordFail(supabase, userId);
    throw new Error("Code de secours invalide");
  });

/** État MFA de l'utilisateur courant. */
export const mfaStatus = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { supabase, userId } = context;
    const { data: superAdminFlag } = await supabase.rpc("has_role", {
      _user_id: userId,
      _role: "super_admin",
    });
    const isSuperAdmin = !!superAdminFlag;
    const { data: prof } = await supabase
      .from("profiles")
      .select("mfa_enrolled_at, mfa_required")
      .eq("id", userId)
      .maybeSingle();
    const enrolled = !!prof?.mfa_enrolled_at;
    const required = !!prof?.mfa_required;
    let sessionValid = false;
    if (enrolled) {
      const key = bearerSessionKey();
      const { data: sess } = await supabase
        .from("mfa_session_validations")
        .select("id, expires_at, revoked_at")
        .eq("user_id", userId)
        .eq("session_token", key)
        .is("revoked_at", null)
        .order("validated_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      sessionValid = !!(sess && new Date(sess.expires_at) > new Date());
    }
    const { count: remainingCodes } = await supabase
      .from("mfa_backup_codes")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .is("used_at", null);
    return {
      enrolled,
      sessionValid,
      remainingBackupCodes: remainingCodes ?? 0,
      isSuperAdmin,
      required,
      exempt: isSuperAdmin || !required,
    };
  });

/** Régénère les 10 codes de secours (invalide les anciens). */
export const mfaRegenerateBackupCodes = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { supabase, userId } = context;
    await supabase.from("mfa_backup_codes").delete().eq("user_id", userId);
    const plain = Array.from({ length: BACKUP_COUNT }, genBackupCode);
    const rows = await Promise.all(
      plain.map(async (c) => ({ user_id: userId, code_hash: await bcrypt.hash(c, 10) })),
    );
    const ins = await supabase.from("mfa_backup_codes").insert(rows);
    if (ins.error) throw new Error(ins.error.message);
    return { backupCodes: plain };
  });

async function assertSuperAdmin(supabase: SB, userId: string) {
  const sa = await supabase.rpc("has_role", { _user_id: userId, _role: "super_admin" });
  if (sa.data) return;
  // Accepte aussi le rôle RBAC v2 "administrateur" (non présent dans l'enum app_role).
  const { data: adm } = await supabase
    .from("rbac_user_roles")
    .select("rbac_roles!inner(code, actif)")
    .eq("user_id", userId)
    .eq("rbac_roles.code", "administrateur")
    .maybeSingle();
  if (adm) return;
  throw new Error("Réservé au super administrateur");
}

/** Super admin : force la ré-enrôlement d'un utilisateur. */
export const mfaAdminResetUser = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ targetUserId: z.string().uuid() }).parse(raw))
  .handler(async ({ data, context }) => {
    await assertSuperAdmin(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await supabaseAdmin.from("two_fa_secrets").delete().eq("user_id", data.targetUserId);
    await supabaseAdmin.from("mfa_backup_codes").delete().eq("user_id", data.targetUserId);
    await supabaseAdmin
      .from("mfa_session_validations")
      .update({ revoked_at: new Date().toISOString() })
      .eq("user_id", data.targetUserId)
      .is("revoked_at", null);
    await supabaseAdmin
      .from("mfa_otp_attempts")
      .upsert({ user_id: data.targetUserId, fail_count: 0, locked_until: null });
    await supabaseAdmin
      .from("profiles")
      .update({ mfa_enrolled_at: null })
      .eq("id", data.targetUserId);
    return { ok: true };
  });

/** Super admin : révoque toutes les sessions MFA d'un utilisateur. */
export const mfaAdminRevokeSessions = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ targetUserId: z.string().uuid() }).parse(raw))
  .handler(async ({ data, context }) => {
    await assertSuperAdmin(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { error } = await supabaseAdmin
      .from("mfa_session_validations")
      .update({ revoked_at: new Date().toISOString() })
      .eq("user_id", data.targetUserId)
      .is("revoked_at", null);
    if (error) throw new Error(error.message);
    return { ok: true };
  });

/** Liste des utilisateurs avec statut MFA (super admin). */
export const mfaAdminListUsers = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    await assertSuperAdmin(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: profs, error } = await supabaseAdmin
      .from("profiles")
      .select("id, email, nom_complet, mfa_enrolled_at, mfa_required, actif")
      .order("nom_complet", { ascending: true });
    if (error) throw new Error(error.message);
    return { users: profs ?? [] };
  });

/** Super admin : active/désactive l'obligation de MFA pour un utilisateur. */
export const mfaAdminSetRequired = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) =>
    z.object({ targetUserId: z.string().uuid(), required: z.boolean() }).parse(raw),
  )
  .handler(async ({ data, context }) => {
    await assertSuperAdmin(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { error } = await supabaseAdmin
      .from("profiles")
      .update({ mfa_required: data.required })
      .eq("id", data.targetUserId);
    if (error) throw new Error(error.message);
    // Si on désactive, on révoque les sessions MFA en cours pour propre reset.
    if (!data.required) {
      await supabaseAdmin
        .from("mfa_session_validations")
        .update({ revoked_at: new Date().toISOString() })
        .eq("user_id", data.targetUserId)
        .is("revoked_at", null);
    }
    return { ok: true };
  });