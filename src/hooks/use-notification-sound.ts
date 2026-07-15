import { getCurrentUser } from "@/lib/current-user";
import { useCallback, useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";

export const MELODIES = [
  { id: "melodie1_cristal", label: "Cristal (ascendant)", file: "/sounds/melodie1_cristal.mp3" },
  { id: "melodie2_cloche", label: "Cloche douce", file: "/sounds/melodie2_cloche.mp3" },
  { id: "melodie3_arpege", label: "Arpège lumineux", file: "/sounds/melodie3_arpege.mp3" },
  { id: "melodie4_alerte", label: "Alerte double", file: "/sounds/melodie4_alerte.mp3" },
  { id: "melodie5_zen", label: "Zen descendant", file: "/sounds/melodie5_zen.mp3" },
] as const;

export type MelodieId = (typeof MELODIES)[number]["id"];

function melodieFile(id: string): string {
  return MELODIES.find((m) => m.id === id)?.file ?? MELODIES[0].file;
}

function defaultMelodieForUser(userId: string | undefined): MelodieId {
  if (!userId) return MELODIES[0].id;
  let h = 0;
  for (let i = 0; i < userId.length; i++) h = (h * 31 + userId.charCodeAt(i)) >>> 0;
  return MELODIES[h % MELODIES.length].id;
}

export type NotificationPrefs = {
  son_actif: boolean;
  volume: number;
  types_desactives: string[];
  modules_desactives: string[];
  notifs_navigateur: boolean;
  son_notification: MelodieId;
};

const DEFAULT_PREFS: NotificationPrefs = {
  son_actif: true,
  volume: 70,
  types_desactives: [],
  modules_desactives: [],
  notifs_navigateur: false,
  son_notification: MELODIES[0].id,
};

let cachedPrefs: NotificationPrefs | null = null;

export async function loadPrefs(): Promise<NotificationPrefs> {
  if (cachedPrefs) return cachedPrefs;
  const { data: auth } = await getCurrentUser();
  const uid = auth.user?.id;
  if (!uid) return DEFAULT_PREFS;
  const { data } = await supabase
    .from("notification_preferences" as never)
    .select("*")
    .eq("user_id", uid)
    .maybeSingle();
  const base = { ...DEFAULT_PREFS, son_notification: defaultMelodieForUser(uid) };
  cachedPrefs = { ...base, ...(data ?? {}) } as NotificationPrefs;
  return cachedPrefs;
}

export function invalidatePrefsCache() {
  cachedPrefs = null;
}

export function useNotificationSound() {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const unlockedRef = useRef(false);

  useEffect(() => {
    audioRef.current = new Audio(melodieFile(MELODIES[0].id));
    audioRef.current.preload = "auto";
    const unlock = () => {
      if (unlockedRef.current || !audioRef.current) return;
      const a = audioRef.current;
      a.volume = 0;
      a.play()
        .then(() => {
          a.pause();
          a.currentTime = 0;
          unlockedRef.current = true;
        })
        .catch(() => {
          /* ignore */
        });
    };
    window.addEventListener("click", unlock, { once: true });
    window.addEventListener("keydown", unlock, { once: true });
    window.addEventListener("touchstart", unlock, { once: true });
    return () => {
      window.removeEventListener("click", unlock);
      window.removeEventListener("keydown", unlock);
      window.removeEventListener("touchstart", unlock);
    };
  }, []);

  const play = useCallback(
    async (priorite?: string, overrideMelodie?: string, overrideVolume?: number) => {
      const prefs = await loadPrefs();
      if (!prefs.son_actif) return;
      if (!audioRef.current) return;
      const targetSrc = melodieFile(overrideMelodie ?? prefs.son_notification);
      const absolute = new URL(targetSrc, window.location.origin).href;
      if (audioRef.current.src !== absolute) audioRef.current.src = targetSrc;
      try {
        audioRef.current.currentTime = 0;
        const vol = overrideVolume ?? prefs.volume;
        const base = Math.max(0, Math.min(1, vol / 100));
        audioRef.current.volume = priorite === "critique" ? Math.min(1, base * 1.2) : base;
        await audioRef.current.play();
      } catch {
        /* ignore autoplay errors */
      }
    },
    [],
  );

  return { play };
}
