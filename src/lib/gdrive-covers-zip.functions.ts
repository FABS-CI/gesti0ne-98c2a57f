// @ts-nocheck
import { createServerFn } from "@tanstack/react-start";
import JSZip from "jszip";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { getOrCreateBackupFolder } from "@/lib/gdrive-folder";

// Buckets métier à inclure dans le ZIP binaires (on exclut les buckets database_export_*).
const DEFAULT_BUCKETS = [
  "product-covers",
  "avatars",
  "employe-photos",
  "employe-documents",
];

async function uploadZipToDrive(
  fileName: string,
  zipBytes: Uint8Array,
  description: string,
  LOVABLE_API_KEY: string,
  GDRIVE_KEY: string,
  folderId: string,
) {
  const boundary = `----lovable-${crypto.randomUUID()}`;
  const metadata = {
    name: fileName,
    mimeType: "application/zip",
    description,
    parents: [folderId],
  };
  const enc = new TextEncoder();
  const head = enc.encode(
    `--${boundary}\r\n` +
      `Content-Type: application/json; charset=UTF-8\r\n\r\n` +
      JSON.stringify(metadata) +
      `\r\n--${boundary}\r\n` +
      `Content-Type: application/zip\r\n\r\n`,
  );
  const tail = enc.encode(`\r\n--${boundary}--`);
  const body = new Uint8Array(head.length + zipBytes.length + tail.length);
  body.set(head, 0);
  body.set(zipBytes, head.length);
  body.set(tail, head.length + zipBytes.length);

  const res = await fetch(
    "https://connector-gateway.lovable.dev/google_drive/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink,size",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LOVABLE_API_KEY}`,
        "X-Connection-Api-Key": GDRIVE_KEY,
        "Content-Type": `multipart/related; boundary=${boundary}`,
      },
      body,
    },
  );
  if (!res.ok) {
    throw new Error(`Google Drive [${res.status}]: ${await res.text()}`);
  }
  return (await res.json()) as {
    id: string;
    name: string;
    webViewLink?: string;
    size?: string;
  };
}

export const exportStorageBinariesZip = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { supabase, userId } = context;
    const { data: isAdmin } = await supabase.rpc("has_role", {
      _user_id: userId,
      _role: "super_admin",
    });
    if (isAdmin !== true) throw new Response("Forbidden", { status: 403 });

    const LOVABLE_API_KEY = process.env.LOVABLE_API_KEY;
    const GDRIVE_KEY = process.env.GOOGLE_DRIVE_API_KEY;
    if (!LOVABLE_API_KEY || !GDRIVE_KEY) {
      throw new Error("Connecteur Google Drive non configuré");
    }

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

    async function listAll(bucketId: string, prefix = ""): Promise<string[]> {
      const out: string[] = [];
      let offset = 0;
      const pageSize = 1000;
      while (true) {
        const { data: entries, error } = await supabaseAdmin.storage
          .from(bucketId)
          .list(prefix, {
            limit: pageSize,
            offset,
            sortBy: { column: "name", order: "asc" },
          });
        if (error) throw new Error(`storage.list(${bucketId}/${prefix}): ${error.message}`);
        if (!entries || entries.length === 0) break;
        for (const entry of entries) {
          const fullPath = prefix ? `${prefix}/${entry.name}` : entry.name;
          if (entry.id === null || entry.metadata == null) {
            const sub = await listAll(bucketId, fullPath);
            out.push(...sub);
          } else {
            out.push(fullPath);
          }
        }
        if (entries.length < pageSize) break;
        offset += pageSize;
      }
      return out;
    }

    const zip = new JSZip();
    const summary: Array<{ bucket: string; files: number; bytes: number }> = [];
    let totalFiles = 0;
    let totalBytes = 0;

    for (const bucketId of DEFAULT_BUCKETS) {
      // Skip si bucket absent
      const { data: buckets } = await supabaseAdmin.storage.listBuckets();
      if (!buckets?.some((b) => b.id === bucketId)) continue;

      const paths = await listAll(bucketId);
      let bucketBytes = 0;
      const folder = zip.folder(bucketId);
      if (!folder) continue;

      for (const path of paths) {
        const { data: blob, error } = await supabaseAdmin.storage
          .from(bucketId)
          .download(path);
        if (error || !blob) {
          console.warn(`skip ${bucketId}/${path}: ${error?.message ?? "empty"}`);
          continue;
        }
        const buf = new Uint8Array(await blob.arrayBuffer());
        folder.file(path, buf);
        bucketBytes += buf.length;
      }
      summary.push({ bucket: bucketId, files: paths.length, bytes: bucketBytes });
      totalFiles += paths.length;
      totalBytes += bucketBytes;
    }

    // Ajoute un manifest.json au ZIP
    zip.file(
      "manifest.json",
      JSON.stringify(
        {
          generated_at: new Date().toISOString(),
          buckets: summary,
          total_files: totalFiles,
          total_bytes: totalBytes,
        },
        null,
        2,
      ),
    );

    const zipBytes = await zip.generateAsync({
      type: "uint8array",
      compression: "DEFLATE",
      compressionOptions: { level: 6 },
    });

    const folderId = await getOrCreateBackupFolder(LOVABLE_API_KEY, GDRIVE_KEY);
    if (!folderId) throw new Error("Dossier Google Drive introuvable");

    const stamp = new Date().toISOString().slice(0, 10);
    const uploaded = await uploadZipToDrive(
      `storage_binaries_${stamp}.zip`,
      zipBytes,
      `ERP GESTI-ONE binaires Storage (${totalFiles} fichiers, ${(totalBytes / 1024 / 1024).toFixed(1)} Mo décompressés)`,
      LOVABLE_API_KEY,
      GDRIVE_KEY,
      folderId,
    );

    return {
      buckets: summary,
      total_files: totalFiles,
      total_bytes: totalBytes,
      zip_bytes: zipBytes.length,
      drive: { id: uploaded.id, url: uploaded.webViewLink ?? null },
    };
  });
