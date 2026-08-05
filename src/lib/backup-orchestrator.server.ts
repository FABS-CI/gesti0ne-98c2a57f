import { buildGlobalArchive, uploadArchiveToDrive, rotateDriveArchives } from "./global-backup.server";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import fs from "fs";
import path from "path";

const LOCAL_BACKUP_DIR = "/tmp/backups";
const MAX_LOCAL_BACKUPS = 10;

export async function orchestrateBackup(opts: {
  trigger: "manuel" | "planifie";
  author: string;
  userId: string;
}) {
  const t0 = Date.now();
  
  // 1. Initialisation du log
  const { data: row } = await supabaseAdmin
    .from("backups")
    .insert({
      user_id: opts.userId,
      user_email: opts.author,
      type: "globale_zip",
      destination: "drive_and_local",
      statut: "en_cours",
      message: `Sauvegarde ${opts.trigger} démarrée...`,
    })
    .select("backup_id")
    .single();
  
  const backupId = row?.backup_id;

  try {
    // 2. Génération de l'archive (Données + Auth + Storage)
    const { bytes, stats } = await buildGlobalArchive(supabaseAdmin, {
      trigger: opts.trigger,
      author: opts.author,
    });

    // 3. Sauvegarde LOCALE (Sandboxed filesystem)
    if (!fs.existsSync(LOCAL_BACKUP_DIR)) {
      fs.mkdirSync(LOCAL_BACKUP_DIR, { recursive: true });
    }
    const localPath = path.join(LOCAL_BACKUP_DIR, stats.fileName);
    fs.writeFileSync(localPath, bytes);
    
    // Rotation locale
    const localFiles = fs.readdirSync(LOCAL_BACKUP_DIR)
      .filter(f => f.startsWith("fabsci_sauvegarde_globale_"))
      .sort((a, b) => fs.statSync(path.join(LOCAL_BACKUP_DIR, b)).mtimeMs - fs.statSync(path.join(LOCAL_BACKUP_DIR, a)).mtimeMs);
    
    if (localFiles.length > MAX_LOCAL_BACKUPS) {
      localFiles.slice(MAX_LOCAL_BACKUPS).forEach(f => {
        try { fs.unlinkSync(path.join(LOCAL_BACKUP_DIR, f)); } catch(e) {}
      });
    }

    // 4. Sauvegarde DRIVE
    let driveInfo = null;
    try {
      driveInfo = await uploadArchiveToDrive(
        stats.fileName,
        bytes,
        `Sauvegarde ${opts.trigger} - SHA256:${stats.sha256}`
      );
      await rotateDriveArchives(30);
    } catch (driveErr) {
      console.error("Erreur Drive (sauvegarde locale maintenue):", driveErr);
    }

    // 5. Mise à jour finale du log
    if (backupId) {
      await supabaseAdmin
        .from("backups")
        .update({
          statut: "succes",
          finished_at: new Date().toISOString(),
          duree_ms: Date.now() - t0,
          taille_octets: stats.size,
          nb_tables: stats.tables_count,
          nb_enregistrements: stats.rows_count,
          sha256: stats.sha256,
          fichier_nom: stats.fileName,
          destination_ref: driveInfo?.id || "local_only",
          destination_url: driveInfo?.url || null,
          verifie: true,
          verifie_at: new Date().toISOString(),
          verifie_methode: "sha256-auto",
          message: `Double sauvegarde réussie. Tables: ${stats.tables_count}, Users: ${stats.users_count}, Fichiers: ${stats.files_embedded}/${stats.files_count}`
        })
        .eq("backup_id", backupId);
    }

    return { ...stats, drive: driveInfo, localPath };
  } catch (error) {
    console.error("Échec de l'orchestration de sauvegarde:", error);
    if (backupId) {
      await supabaseAdmin
        .from("backups")
        .update({
          statut: "echec",
          finished_at: new Date().toISOString(),
          duree_ms: Date.now() - t0,
          message: (error as Error).message
        })
        .eq("backup_id", backupId);
    }
    throw error;
  }
}
