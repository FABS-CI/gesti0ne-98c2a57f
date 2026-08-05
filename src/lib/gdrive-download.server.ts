import { supabaseAdmin } from "@/integrations/supabase/client.server";

export async function downloadDriveFileRaw(fileId: string): Promise<Uint8Array> {
  const LOVABLE_API_KEY = process.env.LOVABLE_API_KEY;
  const GDRIVE_KEY = process.env.GOOGLE_DRIVE_API_KEY;
  if (!LOVABLE_API_KEY || !GDRIVE_KEY) throw new Error("Connecteur Drive non configuré");

  const res = await fetch(
    `https://connector-gateway.lovable.dev/google_drive/drive/v3/files/${fileId}?alt=media`,
    {
      headers: {
        Authorization: `Bearer ${LOVABLE_API_KEY}`,
        "X-Connection-Api-Key": GDRIVE_KEY,
      },
    }
  );

  if (!res.ok) throw new Error(`Google Drive download failed [${res.status}]`);
  const buf = await res.arrayBuffer();
  return new Uint8Array(buf);
}
