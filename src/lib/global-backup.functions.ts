// @ts-nocheck
import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

/**
 * Sauvegarde globale manuelle (super_admin) : construit l'archive ZIP
 * complète, l'envoie sur Google Drive et journalise l'opération.
 */
export const runGlobalBackup = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { supabase, userId, claims } = context;
    const { data: isAdmin } = await supabase.rpc("has_role_compat", {
      _user_id: userId,
      _role: "super_admin",
    });
    if (isAdmin !== true) throw new Response("Forbidden", { status: 403 });

    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { buildGlobalArchive, uploadArchiveToDrive, rotateDriveArchives } = await import(
      "@/lib/global-backup.server"
    );

    const t0 = Date.now();
    const email = (claims as { email?: string } | null)?.email ?? "super_admin";
    const { data: row } = await supabaseAdmin
      .from("backups")
      .insert({
        user_id: userId,
        user_email: email,
        type: "globale_zip",
        destination: "google_drive",
        statut: "en_cours",
        message: "Sauvegarde globale (données + comptes + fichiers + configuration)",
      })
      .select("backup_id")
      .single();
    const backupId = row?.backup_id as string | undefined;

    try {
      const { bytes, stats } = await buildGlobalArchive(supabaseAdmin, {
        trigger: "manuel",
        author: email,
      });
      const drive = await uploadArchiveToDrive(
        stats.fileName,
        bytes,
        `ERP FABS-CI archive globale sha256=${stats.sha256}`,
      );
      const purged = await rotateDriveArchives(30);

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
            destination_ref: drive.id,
            destination_url: drive.url,
            verifie: true,
            verifie_at: new Date().toISOString(),
            verifie_methode: "sha256-auto",
            message: `Archive globale : ${stats.tables_count} tables, ${stats.rows_count} enregistrements, ${stats.users_count} comptes, ${stats.files_embedded}/${stats.files_count} fichiers inclus`,
          })
          .eq("backup_id", backupId);
      }
      return { ...stats, drive, purged };
    } catch (e) {
      if (backupId) {
        await supabaseAdmin
          .from("backups")
          .update({
            statut: "echec",
            finished_at: new Date().toISOString(),
            duree_ms: Date.now() - t0,
            message: (e as Error).message,
          })
          .eq("backup_id", backupId);
      }
      throw new Error((e as Error).message);
    }
  });
