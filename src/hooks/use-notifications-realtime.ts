import { useEffect } from "react";
import { useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";
import { TYPE_LABEL, type Notification } from "@/lib/notifications-api";
import { loadPrefs, useNotificationSound } from "@/hooks/use-notification-sound";

/**
 * Écoute globale des nouvelles notifications :
 * - joue un son
 * - affiche un toast
 * - déclenche une notification navigateur si l'onglet est masqué
 * - invalide les caches
 */
export function useNotificationsRealtime() {
  const qc = useQueryClient();
  const nav = useNavigate();
  const { user } = useAuth();
  const { play } = useNotificationSound();

  useEffect(() => {
    if (!user?.id) return;
    const channel = supabase
      .channel("notifications-global")
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "notifications" },
        async (payload) => {
          const n = payload.new as Notification & {
            user_id: string | null;
            module?: string | null;
            priorite?: string | null;
            lien?: string | null;
          };

          // RÈGLE ABSOLUE : Pas de notification pour les actions du Super Admin.
          // Note: On utilise un cast temporaire car le type Notification sera mis à jour
          // avec la colonne is_super_admin dans le schéma.
          if ((n as any).is_super_admin === true) return;

          // Ciblage: la policy RLS filtre déjà, mais on double-check côté client
          // (la souscription pourrait recevoir des broadcasts avant filtre).
          if (n.user_id && n.user_id !== user.id) return;

          const prefs = await loadPrefs();
          if (n.module && prefs.modules_desactives.includes(n.module)) return;
          if (prefs.types_desactives.includes(n.type_notification)) return;

          play(n.priorite ?? undefined);

          const meta = TYPE_LABEL[n.type_notification] ?? TYPE_LABEL.info;
          toast(n.titre, {
            description: n.message ?? undefined,
            style: { borderLeft: `4px solid ${meta.color}` },
            action: n.lien
              ? {
                  label: "Ouvrir",
                  onClick: () => nav({ to: n.lien as string }).catch(() => {}),
                }
              : undefined,
          });

          // Notification navigateur (onglet en arrière-plan)
          if (
            prefs.notifs_navigateur &&
            typeof window !== "undefined" &&
            "Notification" in window &&
            Notification.permission === "granted" &&
            document.hidden
          ) {
            try {
              new Notification(n.titre, {
                body: n.message ?? "",
                icon: "/favicon.ico",
                tag: n.notification_id,
              });
            } catch {
              /* ignore */
            }
          }

          qc.invalidateQueries({ queryKey: ["notifications-unread"] });
          qc.invalidateQueries({ queryKey: ["notifications-recent"] });
          qc.invalidateQueries({ queryKey: ["notifications"] });
        },
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [user?.id, qc, nav, play]);
}
