// Résout (ou crée) le dossier "DONNEE GESTI-ONE" à la racine du Drive lié.
// Renvoie l'ID du dossier, ou null en cas d'échec (upload continuera en racine).

export const GDRIVE_BACKUP_FOLDER_NAME = "DONNEE GESTI-ONE";

const GATEWAY = "https://connector-gateway.lovable.dev/google_drive";

let cachedFolderId: string | null = null;

export async function getOrCreateBackupFolder(
  lovableApiKey: string,
  gdriveKey: string,
): Promise<string | null> {
  if (cachedFolderId) return cachedFolderId;

  const headers = {
    Authorization: `Bearer ${lovableApiKey}`,
    "X-Connection-Api-Key": gdriveKey,
  } as const;

  try {
    // 1. Recherche dossier existant
    const q = encodeURIComponent(
      `mimeType='application/vnd.google-apps.folder' and name='${GDRIVE_BACKUP_FOLDER_NAME}' and trashed=false`,
    );
    const findRes = await fetch(
      `${GATEWAY}/drive/v3/files?q=${q}&fields=files(id,name)&pageSize=1`,
      { headers },
    );
    if (findRes.ok) {
      const found = (await findRes.json()) as { files?: Array<{ id: string }> };
      if (found.files && found.files.length > 0) {
        cachedFolderId = found.files[0].id;
        return cachedFolderId;
      }
    }

    // 2. Création si absent
    const createRes = await fetch(`${GATEWAY}/drive/v3/files?fields=id`, {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({
        name: GDRIVE_BACKUP_FOLDER_NAME,
        mimeType: "application/vnd.google-apps.folder",
      }),
    });
    if (!createRes.ok) {
      console.error(
        `Création dossier Drive échouée [${createRes.status}]: ${await createRes.text()}`,
      );
      return null;
    }
    const created = (await createRes.json()) as { id: string };
    cachedFolderId = created.id;
    return cachedFolderId;
  } catch (e) {
    console.error("getOrCreateBackupFolder error:", (e as Error).message);
    return null;
  }
}
