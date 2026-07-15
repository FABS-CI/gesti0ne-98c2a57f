import { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@/hooks/use-auth";
import { supabase } from "@/integrations/supabase/client";
import { Sun, CloudSun, Moon } from "lucide-react";
import { useAvatarUrl } from "@/hooks/use-avatar-url";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";

function getGreeting(hour: number) {
  if (hour >= 5 && hour < 12) {
    return {
      Icon: Sun,
      text: (name: string) =>
        `Bonjour, ${name} ! Nous vous souhaitons une excellente journée de travail.`,
      bg: "bg-[linear-gradient(120deg,#0b3d91_0%,#1e6bd6_45%,#f59e0b_100%)]",
      iconTint: "text-amber-300",
    };
  }
  if (hour >= 12 && hour < 18) {
    return {
      Icon: CloudSun,
      text: (name: string) =>
        `Bon après-midi, ${name} ! Heureux de vous retrouver. Nous vous souhaitons une excellente continuation.`,
      bg: "bg-[linear-gradient(120deg,#0b3d91_0%,#2563eb_50%,#f97316_100%)]",
      iconTint: "text-orange-200",
    };
  }
  return {
    Icon: Moon,
    text: (name: string) =>
      `Bonsoir, ${name} ! Bienvenue dans GESTI-one. Nous vous souhaitons une agréable soirée de travail.`,
    bg: "bg-[linear-gradient(120deg,#0a1f4d_0%,#0b3d91_55%,#c2410c_100%)]",
    iconTint: "text-indigo-200",
  };
}

export function WelcomeGreeting() {
  const { user } = useAuth();
  const [hour, setHour] = useState(() => new Date().getHours());

  useEffect(() => {
    const id = setInterval(() => setHour(new Date().getHours()), 60_000);
    return () => clearInterval(id);
  }, []);

  const { data: profile } = useQuery({
    queryKey: ["profile-name", user?.id],
    enabled: !!user?.id,
    staleTime: 5 * 60_000,
    queryFn: async () => {
      const { data } = await supabase
        .from("profiles")
        .select("nom_complet, avatar_url")
        .eq("id", user!.id)
        .maybeSingle();
      return data;
    },
  });
  const { data: avatarUrl } = useAvatarUrl(profile?.avatar_url);

  const name = useMemo(() => {
    const meta = (user?.user_metadata ?? {}) as Record<string, unknown>;
    const candidates = [
      profile?.nom_complet,
      meta.prenom,
      meta.first_name,
      meta.full_name,
      meta.name,
      user?.email?.split("@")[0],
    ];
    const found = candidates.find((v): v is string => typeof v === "string" && v.trim().length > 0);
    const raw = found ?? "Utilisateur";
    // Prénom uniquement pour un rendu naturel
    return raw.split(/\s+/)[0];
  }, [user, profile]);

  const fallbackInitials = useMemo(() => {
    return name.slice(0, 2).toUpperCase();
  }, [name]);

  const g = getGreeting(hour);

  return (
    <div
      className={`animate-fade-in relative overflow-hidden rounded-2xl border border-white/10 p-5 text-white shadow-lg ${g.bg}`}
      role="status"
      aria-live="polite"
    >
      {/* halo décoratif */}
      <div
        aria-hidden
        className="pointer-events-none absolute -right-16 -top-16 h-48 w-48 rounded-full bg-white/10 blur-3xl"
      />
      <div className="relative flex items-center gap-4">
        <Avatar className="h-12 w-12 shrink-0 ring-1 ring-white/20">
          {avatarUrl ? <AvatarImage src={avatarUrl} alt={name} /> : null}
          <AvatarFallback className="bg-white/15 text-white text-sm font-semibold backdrop-blur-sm">
            {fallbackInitials}
          </AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1">
          <p className="text-base font-semibold leading-tight sm:text-lg">{g.text(name)}</p>
        </div>
        <g.Icon className={`h-7 w-7 shrink-0 ${g.iconTint}`} aria-hidden />
      </div>
    </div>
  );
}
