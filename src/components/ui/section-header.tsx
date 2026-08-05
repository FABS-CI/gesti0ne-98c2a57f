import type { ComponentType, ReactNode } from "react";
import { CardHeader, CardTitle } from "@/components/ui/card";

interface SectionHeaderProps {
  icon: ComponentType<{ className?: string }>;
  title: string;
  color: string;
  action?: ReactNode;
}

/**
 * Bandeau de section avec accent latéral coloré et icône thématique.
 * Utilisé pour harmoniser les formulaires et pages de détail.
 */
export function SectionHeader({ icon: Icon, title, color, action }: SectionHeaderProps) {
  return (
    <CardHeader className="relative pl-4 sm:pl-5">
      <span
        aria-hidden
        className="absolute inset-y-0 left-0 w-1"
        style={{ backgroundColor: color }}
      />
      <div className="flex flex-wrap items-center justify-between gap-3">
        <CardTitle className="flex items-center gap-2 text-sm sm:text-base">
          <span
            className="grid h-7 w-7 shrink-0 place-items-center rounded-md text-white shadow-sm"
            style={{ backgroundColor: color }}
          >
            <Icon className="h-4 w-4" />
          </span>
          <span className="truncate">{title}</span>
        </CardTitle>
        <div className="flex shrink-0 items-center gap-2 ml-auto">
          {action}
        </div>
      </div>
    </CardHeader>
  );
}
