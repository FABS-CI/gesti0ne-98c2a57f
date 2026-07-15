import { useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";
import { findShortcut } from "@/lib/shortcuts-catalog";

/**
 * Fire-and-forget tracking of user actions to feed smart shortcuts.
 * Never throws; failures are silently ignored.
 */
export function useTrackAction() {
  return useCallback(
    async (
      key: string,
      extra?: { module?: string; label?: string; icon?: string; href?: string },
    ) => {
      try {
        const def = findShortcut(key);
        await supabase.rpc("track_user_action", {
          _action_key: key,
          _module: extra?.module ?? def?.module,
          _label: extra?.label ?? def?.label,
          _icon: extra?.icon ?? def?.iconName,
          _href: extra?.href ?? def?.href,
        });
      } catch {
        // silent
      }
    },
    [],
  );
}
