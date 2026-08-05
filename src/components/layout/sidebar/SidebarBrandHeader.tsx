import { X } from "lucide-react";
import fabsLogo from "@/assets/fabs-logo.png";
import { SidebarHeader, useSidebar } from "@/components/ui/sidebar";

export function SidebarBrandHeader({ accentGrad }: { accentGrad: string | null }) {
  const { isMobile, setOpenMobile } = useSidebar();
  return (
    <SidebarHeader
      className="relative px-4 py-5"
      style={{ background: "#111827", borderBottom: "1px solid rgba(255,255,255,0.06)" }}
    >
      {isMobile && (
        <button
          type="button"
          aria-label="Fermer le menu"
          onClick={() => setOpenMobile(false)}
          className="absolute right-3 top-3 flex h-11 w-11 items-center justify-center rounded-full text-white"
          style={{ background: "rgba(255,255,255,0.08)" }}
        >
          <X className="h-6 w-6" />
        </button>
      )}
      <div className="flex flex-1 flex-col items-center gap-2.5">
        <img
          src={fabsLogo}
          alt="Logo Éditions FABS-CI"
          width={72}
          height={72}
          className="h-18 w-18 shrink-0 rounded-xl bg-white object-contain p-1.5"
          style={{ width: 72, height: 72 }}
          decoding="async"
        />
        <span
          style={{
            fontSize: "15px",
            fontWeight: 800,
            color: "#F8FAFC",
            letterSpacing: "0.08em",
          }}
        >
          Editions FABS-CI
        </span>
        <div
          style={{
            height: "3px",
            width: "52px",
            borderRadius: "99px",
            background: accentGrad ?? "rgba(255,255,255,0.1)",
            transition: "background 0.4s ease",
          }}
        />
      </div>
    </SidebarHeader>
  );
}
