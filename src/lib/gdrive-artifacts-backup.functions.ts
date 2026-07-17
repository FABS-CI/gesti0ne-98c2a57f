// @ts-nocheck
import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { getOrCreateBackupFolder } from "@/lib/gdrive-folder";

async function uploadJsonToDrive(
  fileName: string,
  json: string,
  description: string,
  LOVABLE_API_KEY: string,
  GDRIVE_KEY: string,
  folderId: string,
) {
  const boundary = `----lovable-${crypto.randomUUID()}`;
  const metadata = {
    name: fileName,
    mimeType: "application/json",
    description,
    parents: [folderId],
  };
  const body =
    `--${boundary}\r\n` +
    `Content-Type: application/json; charset=UTF-8\r\n\r\n` +
    JSON.stringify(metadata) +
    `\r\n--${boundary}\r\n` +
    `Content-Type: application/json\r\n\r\n` +
    json +
    `\r\n--${boundary}--`;
  const res = await fetch(
    "https://connector-gateway.lovable.dev/google_drive/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink",
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
  return (await res.json()) as { id: string; name: string; webViewLink?: string };
}

export const exportCriticalArtifacts = createServerFn({ method: "POST" })
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

    // 1) auth.users export (paginé)
    const users: any[] = [];
    let page = 1;
    while (true) {
      const { data, error } = await supabaseAdmin.auth.admin.listUsers({
        page,
        perPage: 200,
      });
      if (error) throw new Error(`auth.listUsers: ${error.message}`);
      if (!data?.users?.length) break;
      users.push(
        ...data.users.map((u) => ({
          id: u.id,
          email: u.email,
          phone: u.phone,
          role: u.role,
          created_at: u.created_at,
          last_sign_in_at: u.last_sign_in_at,
          email_confirmed_at: u.email_confirmed_at,
          user_metadata: u.user_metadata,
          app_metadata: u.app_metadata,
          identities: (u.identities ?? []).map((i: any) => ({
            provider: i.provider,
            identity_data: i.identity_data,
          })),
        })),
      );
      if (data.users.length < 200) break;
      page += 1;
    }

    // 2) storage manifest (tous buckets) + URLs signées 7 jours
    const { data: buckets, error: bErr } = await supabaseAdmin.storage.listBuckets();
    if (bErr) throw new Error(`listBuckets: ${bErr.message}`);
    const manifest: any = { generated_at: new Date().toISOString(), buckets: [] };

    async function listAll(bucketId: string, prefix = ""): Promise<any[]> {
      const out: any[] = [];
      let offset = 0;
      const pageSize = 1000;
      while (true) {
        const { data: entries, error } = await supabaseAdmin.storage
          .from(bucketId)
          .list(prefix, { limit: pageSize, offset, sortBy: { column: "name", order: "asc" } });
        if (error) throw new Error(`storage.list(${bucketId}/${prefix}): ${error.message}`);
        if (!entries || entries.length === 0) break;
        for (const entry of entries) {
          const fullPath = prefix ? `${prefix}/${entry.name}` : entry.name;
          if (entry.id === null || entry.metadata == null) {
            // folder
            const sub = await listAll(bucketId, fullPath);
            out.push(...sub);
          } else {
            out.push({ path: fullPath, metadata: entry.metadata, created_at: entry.created_at });
          }
        }
        if (entries.length < pageSize) break;
        offset += pageSize;
      }
      return out;
    }

    for (const bucket of buckets ?? []) {
      const rows = await listAll(bucket.id);
      const objects: any[] = [];
      for (const row of rows) {
        const { data: signed } = await supabaseAdmin.storage
          .from(bucket.id)
          .createSignedUrl(row.path, 60 * 60 * 24 * 7);
        objects.push({
          path: row.path,
          size: row.metadata?.size ?? null,
          mimetype: row.metadata?.mimetype ?? null,
          created_at: row.created_at,
          signed_url: signed?.signedUrl ?? null,
          signed_url_expires_days: 7,
        });
      }
      manifest.buckets.push({
        id: bucket.id,
        public: bucket.public,
        objects_count: objects.length,
        objects,
      });
    }


    const stamp = new Date().toISOString().slice(0, 10);
    const folderId = await getOrCreateBackupFolder(LOVABLE_API_KEY, GDRIVE_KEY);
    if (!folderId) throw new Error("Dossier Google Drive introuvable");

    const usersFile = await uploadJsonToDrive(
      `auth_users_${stamp}.json`,
      JSON.stringify({ exported_at: new Date().toISOString(), count: users.length, users }, null, 2),
      `ERP FABS-CI auth.users export (${users.length} comptes)`,
      LOVABLE_API_KEY,
      GDRIVE_KEY,
      folderId,
    );
    const storageFile = await uploadJsonToDrive(
      `storage_manifest_${stamp}.json`,
      JSON.stringify(manifest, null, 2),
      `ERP FABS-CI storage manifest (URLs signées 7 jours)`,
      LOVABLE_API_KEY,
      GDRIVE_KEY,
      folderId,
    );

    return {
      users_count: users.length,
      buckets_count: manifest.buckets.length,
      files_count: manifest.buckets.reduce((s: number, b: any) => s + b.objects_count, 0),
      users_drive: { id: usersFile.id, url: usersFile.webViewLink ?? null },
      storage_drive: { id: storageFile.id, url: storageFile.webViewLink ?? null },
    };
  });
