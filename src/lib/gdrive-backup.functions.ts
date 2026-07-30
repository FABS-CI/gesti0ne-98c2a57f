// @ts-nocheck — schema temporarily reduced after reset; types.ts regenerates when tables come back.
import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { getOrCreateBackupFolder } from "@/lib/gdrive-folder";

type UploadInput = {
  backupId: string;
  fileName: string;
  json: string;
  sha256: string;
};

export const uploadBackupToGoogleDrive = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: UploadInput) => input)
  .handler(async ({ data, context }) => {
    const { supabase, userId } = context;

    // Vérif rôle super_admin
    const { data: isAdmin, error: roleErr } = await supabase.rpc("has_role_compat", {
      _user_id: userId,
      _role: "super_admin",
    });
    if (roleErr || isAdmin !== true) {
      throw new Response("Forbidden", { status: 403 });
    }

    const LOVABLE_API_KEY = process.env.LOVABLE_API_KEY;
    const GDRIVE_KEY = process.env.GOOGLE_DRIVE_API_KEY;
    if (!LOVABLE_API_KEY || !GDRIVE_KEY) {
      throw new Error("Connecteur Google Drive non configuré");
    }

    const folderId = await getOrCreateBackupFolder(LOVABLE_API_KEY, GDRIVE_KEY);
    if (!folderId) {
      throw new Error(
        "Dossier « DONNEE GESTI-ONE » introuvable/non créable — upload annulé pour éviter un fichier à la racine.",
      );
    }

    const boundary = `----lovable-${crypto.randomUUID()}`;
    const metadata = {
      name: data.fileName,
      mimeType: "application/json",
      description: `ERP FABS-CI backup ${data.backupId} sha256=${data.sha256}`,
      parents: [folderId],
    };
    const body =
      `--${boundary}\r\n` +
      `Content-Type: application/json; charset=UTF-8\r\n\r\n` +
      JSON.stringify(metadata) +
      `\r\n--${boundary}\r\n` +
      `Content-Type: application/json\r\n\r\n` +
      data.json +
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
      const errText = await res.text();
      console.error(`Google Drive upload failed [${res.status}]: ${errText}`);
      throw new Error(`Google Drive: ${res.status} ${errText}`);
    }
    const info = (await res.json()) as { id: string; name: string; webViewLink?: string };

    await supabase
      .from("backups")
      .update({
        destination: "google_drive",
        destination_ref: info.id,
        destination_url: info.webViewLink ?? null,
      })
      .eq("backup_id", data.backupId);

    return { id: info.id, url: info.webViewLink ?? null };
  });