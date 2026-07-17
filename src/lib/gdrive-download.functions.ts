// @ts-nocheck
import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const GATEWAY = "https://connector-gateway.lovable.dev/google_drive";

/**
 * Télécharge un fichier depuis Google Drive via le connecteur Lovable
 * et le renvoie en base64 au navigateur.
 *
 * Contourne le blocage de `drive.usercontent.google.com` par certains réseaux
 * (FAI, proxies d'entreprise, DNS filtrants) : le binaire transite par le
 * même domaine que l'app.
 */
export const downloadDriveFile = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: { fileId: string }) => {
    if (!input?.fileId || typeof input.fileId !== "string") {
      throw new Error("fileId requis");
    }
    return { fileId: input.fileId };
  })
  .handler(async ({ data, context }) => {
    const { data: isAdmin } = await context.supabase.rpc("has_role", {
      _user_id: context.userId,
      _role: "super_admin",
    });
    if (isAdmin !== true) throw new Response("Forbidden", { status: 403 });

    const LOVABLE_API_KEY = process.env.LOVABLE_API_KEY;
    const GDRIVE_KEY = process.env.GOOGLE_DRIVE_API_KEY;
    if (!LOVABLE_API_KEY || !GDRIVE_KEY) {
      throw new Error("Connecteur Google Drive non configuré");
    }
    const headers = {
      Authorization: `Bearer ${LOVABLE_API_KEY}`,
      "X-Connection-Api-Key": GDRIVE_KEY,
    };

    // 1) Metadata (nom + mimeType)
    const metaRes = await fetch(
      `${GATEWAY}/drive/v3/files/${encodeURIComponent(data.fileId)}?fields=id,name,mimeType,size`,
      { headers },
    );
    if (!metaRes.ok) {
      throw new Error(`Metadata [${metaRes.status}]: ${await metaRes.text()}`);
    }
    const meta = (await metaRes.json()) as {
      name: string;
      mimeType: string;
      size?: string;
    };

    // 2) Contenu binaire
    const binRes = await fetch(
      `${GATEWAY}/drive/v3/files/${encodeURIComponent(data.fileId)}?alt=media`,
      { headers },
    );
    if (!binRes.ok) {
      throw new Error(`Download [${binRes.status}]: ${await binRes.text()}`);
    }
    const buf = new Uint8Array(await binRes.arrayBuffer());

    // Encodage base64 (chunké pour éviter les stacks overflows sur les gros fichiers)
    let binary = "";
    const chunk = 0x8000;
    for (let i = 0; i < buf.length; i += chunk) {
      binary += String.fromCharCode.apply(null, Array.from(buf.subarray(i, i + chunk)) as any);
    }
    const base64 =
      typeof btoa === "function" ? btoa(binary) : Buffer.from(binary, "binary").toString("base64");

    return {
      name: meta.name,
      mimeType: meta.mimeType || "application/octet-stream",
      size: buf.length,
      base64,
    };
  });
