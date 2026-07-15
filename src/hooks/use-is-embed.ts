import { useEffect, useState } from "react";

/** Retourne true si l'URL contient `?embed=1` — utilisé par les pages imprimables. */
export function useIsEmbed(): boolean {
  const [embed, setEmbed] = useState(false);
  useEffect(() => {
    try {
      const sp = new URLSearchParams(window.location.search);
      setEmbed(sp.get("embed") === "1");
    } catch {
      setEmbed(false);
    }
  }, []);
  return embed;
}
