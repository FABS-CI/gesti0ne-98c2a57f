/**
 * Service serveur de certification numérique des documents.
 * - Empreinte SHA-256 des données canoniques
 * - Signature Ed25519 avec la clé privée du serveur (secret DOC_SIGNING_PRIVATE_KEY)
 * - Jeton de vérification aléatoire de 256 bits, stocké en base uniquement sous forme de hash
 */
import { createHash, createPrivateKey, createPublicKey, randomBytes, sign, verify } from "crypto";
import { canonicalString, toCanonical, type CanonicalDocument } from "./canonical";

export type DocType = "FACTURE" | "PROFORMA" | "COMMANDE" | "BL";

export type CertStatut = "AUTHENTIC" | "REVOKED" | "CANCELLED";

export type VerificationResult =
  | { status: "AUTHENTIC"; document: PublicDocument }
  | { status: "REVOKED" | "CANCELLED"; document: PublicDocument; reason?: string | null }
  | { status: "TAMPERED"; document: PublicDocument }
  | { status: "UNCERTIFIED"; document: PublicDocument }
  | { status: "INVALID" };

export type PublicDocument = {
  docType: string;
  reference: string;
  date: string | null;
  client_nom: string | null;
  representant_nom?: string | null;
  montant: number | null;
  statut_document?: string | null;
  certification_id?: string | null;
  certified_at?: string | null;
  canonical_hash?: string | null;
  signature_algorithm?: string | null;
};

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function newVerificationToken(): { token: string; tokenHash: string } {
  const token = randomBytes(32).toString("base64url"); // 256 bits
  return { token, tokenHash: sha256Hex(token) };
}

function privateKeyObject() {
  const b64 = process.env["DOC_SIGNING_PRIVATE_KEY"];
  if (!b64) throw new Error("Clé de signature indisponible");
  return createPrivateKey({ key: Buffer.from(b64, "base64"), format: "der", type: "pkcs8" });
}

function publicKeyObject(publicKeyB64?: string) {
  const b64 = publicKeyB64 ?? process.env["DOC_SIGNING_PUBLIC_KEY"];
  if (!b64) throw new Error("Clé publique indisponible");
  return createPublicKey({ key: Buffer.from(b64, "base64"), format: "der", type: "spki" });
}

export function signPayload(payload: string): string {
  return sign(null, Buffer.from(payload, "utf8"), privateKeyObject()).toString("base64");
}

export function verifySignature(payload: string, signatureB64: string, publicKeyB64?: string): boolean {
  try {
    return verify(
      null,
      Buffer.from(payload, "utf8"),
      publicKeyObject(publicKeyB64),
      Buffer.from(signatureB64, "base64"),
    );
  } catch {
    return false;
  }
}

/** Construit la représentation canonique + son empreinte pour un document. */
export function buildCanonical(input: Parameters<typeof toCanonical>[0]): {
  canonical: CanonicalDocument;
  payload: string;
  hash: string;
} {
  const canonical = toCanonical(input);
  const payload = canonicalString(canonical);
  return { canonical, payload, hash: sha256Hex(payload) };
}

/** Récupère les données source d'un document depuis la base (service role). */
export async function loadDocumentData(
  reference: string,
): Promise<{ type: DocType; id: string; data: PublicDocument; canonicalInput: Parameters<typeof toCanonical>[0] } | null> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

  const tables: Array<{
    table: string;
    idCol: string;
    type: DocType;
    label: string;
    dateCol: string;
    montantCol: string;
  }> = [
    { table: "factures", idCol: "facture_id", type: "FACTURE", label: "Facture", dateCol: "date_facture", montantCol: "montant_total" },
    { table: "proformas", idCol: "proforma_id", type: "PROFORMA", label: "Proforma", dateCol: "date_proforma", montantCol: "montant_ttc" },
    { table: "commandes", idCol: "commande_id", type: "COMMANDE", label: "Bon de commande", dateCol: "date_commande", montantCol: "montant_total" },
    { table: "bons_livraison", idCol: "bl_id", type: "BL", label: "Bon de livraison", dateCol: "date_bon", montantCol: "montant" },
  ];

  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(reference);

  for (const t of tables) {
    let query = supabaseAdmin.from(t.table as any).select("*");
    query = isUuid
      ? (query as any).or(`${t.idCol}.eq.${reference},reference.ilike.${reference}`)
      : (query as any).ilike("reference", reference);

    const { data } = await (query as any).maybeSingle();
    if (!data) continue;

    const row = data as Record<string, any>;
    const docId = row[t.idCol] as string;

    // Lignes : les factures et BL s'appuient sur les lignes de commande
    let lignes: Array<Record<string, unknown>> = [];
    if (t.type === "FACTURE") {
      const { data: l } = await supabaseAdmin
        .from("commande_lignes" as any)
        .select("designation, quantite, prix_unitaire, total_ligne, total_ht_ligne")
        .eq("facture_id", docId);
      lignes = (l as any) ?? [];
    } else if (t.type === "COMMANDE") {
      const { data: l } = await supabaseAdmin
        .from("commande_lignes")
        .select("designation, quantite, prix_unitaire, total_ligne, total_ht_ligne")
        .eq("commande_id", docId);
      lignes = (l as any) ?? [];
    } else if (t.type === "PROFORMA") {
      const { data: l } = await supabaseAdmin
        .from("proforma_lignes")
        .select("designation, quantite, prix_unitaire, total_ligne")
        .eq("proforma_id", docId);
      lignes = (l as any) ?? [];
    }

    const montant = Number(row[t.montantCol] ?? row.montant_total ?? row.montant_ttc ?? row.montant ?? 0);

    return {
      type: t.type,
      id: docId,
      data: {
        docType: t.label,
        reference: row.reference,
        date: row[t.dateCol] ?? null,
        client_nom: row.client_nom ?? null,
        representant_nom: row.representant_nom ?? null,
        montant,
        statut_document: row.statut ?? null,
      },
      canonicalInput: {
        type: t.type,
        reference: row.reference,
        date: row[t.dateCol],
        client_nom: row.client_nom,
        montant_total: montant,
        lignes,
      },
    };
  }

  return null;
}

/** Certifie un document : empreinte, signature, jeton. Renvoie le jeton en clair une seule fois. */
export async function certifyDocument(
  reference: string,
  userId: string | null,
): Promise<{ token: string; certification_id: string; hash: string }> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const doc = await loadDocumentData(reference);
  if (!doc) throw new Error("Document introuvable");

  const { payload, hash, canonical } = buildCanonical(doc.canonicalInput);
  const signature = signPayload(payload);
  const { token, tokenHash } = newVerificationToken();

  const { data: key } = await supabaseAdmin
    .from("signature_keys" as any)
    .select("key_id")
    .eq("is_active", true)
    .maybeSingle();

  // Version suivante si le document a déjà été certifié
  const { data: prev } = await supabaseAdmin
    .from("document_certifications" as any)
    .select("version")
    .eq("document_type", doc.type)
    .eq("document_id", doc.id)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  const version = ((prev as any)?.version ?? 0) + 1;

  const { data: inserted, error } = await supabaseAdmin
    .from("document_certifications" as any)
    .insert({
      document_type: doc.type,
      document_id: doc.id,
      document_reference: doc.data.reference,
      canonical_hash: hash,
      signature,
      key_id: (key as any)?.key_id ?? null,
      token_hash: tokenHash,
      statut: "AUTHENTIC",
      snapshot: canonical as any,
      certified_by: userId,
      version,
    })
    .select("certification_id")
    .single();

  if (error) throw new Error(error.message);

  return { token, certification_id: (inserted as any).certification_id, hash };
}

export async function revokeCertification(
  certificationId: string,
  userId: string | null,
  reason: string,
): Promise<void> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { error } = await supabaseAdmin
    .from("document_certifications" as any)
    .update({
      statut: "REVOKED",
      revoked_at: new Date().toISOString(),
      revoked_by: userId,
      revocation_reason: reason,
    })
    .eq("certification_id", certificationId);
  if (error) throw new Error(error.message);
}

/** Vérification publique : jeton -> certification -> hash -> signature -> statut. */
export async function verifyByToken(token: string): Promise<VerificationResult> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const tokenHash = sha256Hex(token);

  const { data: cert } = await supabaseAdmin
    .from("document_certifications" as any)
    .select("*, signature_keys(public_key, algorithm)")
    .eq("token_hash", tokenHash)
    .maybeSingle();

  if (!cert) return { status: "INVALID" };
  return evaluateCertification(cert);
}

/**
 * Vérification par référence de document (QR imprimés historiques).
 * Renvoie UNCERTIFIED si le document existe mais n'a jamais été certifié.
 */
export async function verifyByReference(reference: string): Promise<VerificationResult> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

  const doc = await loadDocumentData(reference);
  if (!doc) return { status: "INVALID" };

  const { data: cert } = await supabaseAdmin
    .from("document_certifications" as any)
    .select("*, signature_keys(public_key, algorithm)")
    .eq("document_type", doc.type)
    .eq("document_id", doc.id)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!cert) return { status: "UNCERTIFIED", document: doc.data };
  return evaluateCertification(cert);
}

async function evaluateCertification(cert: unknown): Promise<VerificationResult> {
  const c = cert as any;

  const doc = await loadDocumentData(c.document_reference);
  if (!doc) return { status: "INVALID" };

  const publicDoc: PublicDocument = {
    ...doc.data,
    certification_id: c.certification_id ?? null,
    certified_at: c.certified_at,
    canonical_hash: c.canonical_hash,
    signature_algorithm: c.signature_keys?.algorithm ?? "Ed25519",
  };

  const { payload, hash } = buildCanonical(doc.canonicalInput);
  const signatureOk = verifySignature(
    canonicalStringFromSnapshot(c.snapshot) ?? payload,
    c.signature,
    c.signature_keys?.public_key,
  );

  if (!signatureOk) return { status: "TAMPERED", document: publicDoc };
  if (hash !== c.canonical_hash) return { status: "TAMPERED", document: publicDoc };

  if (c.statut === "REVOKED" || c.statut === "CANCELLED") {
    return { status: c.statut, document: publicDoc, reason: c.revocation_reason };
  }

  return { status: "AUTHENTIC", document: publicDoc };
}

function canonicalStringFromSnapshot(snapshot: unknown): string | null {
  if (!snapshot || typeof snapshot !== "object") return null;
  try {
    return canonicalString(snapshot as CanonicalDocument);
  } catch {
    return null;
  }
}

/** Journalise une vérification publique (sans donnée personnelle en clair). */
export async function logVerification(params: {
  certificationId?: string | null;
  reference?: string | null;
  result: string;
  ip?: string | null;
  userAgent?: string | null;
}): Promise<void> {
  try {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await supabaseAdmin.from("document_verification_logs" as any).insert({
      certification_id: params.certificationId ?? null,
      document_reference: params.reference ?? null,
      result: params.result,
      ip_hash: params.ip ? sha256Hex(params.ip) : null,
      user_agent: params.userAgent?.slice(0, 200) ?? null,
    });
  } catch {
    // la journalisation ne doit jamais bloquer une vérification
  }
}

/** Limitation de débit simple : 30 vérifications / 10 min par adresse. */
export async function isRateLimited(ip: string | null): Promise<boolean> {
  if (!ip) return false;
  try {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const since = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const { count } = await supabaseAdmin
      .from("document_verification_logs" as any)
      .select("log_id", { count: "exact", head: true })
      .eq("ip_hash", sha256Hex(ip))
      .gte("created_at", since);
    return (count ?? 0) > 30;
  } catch {
    return false;
  }
}
