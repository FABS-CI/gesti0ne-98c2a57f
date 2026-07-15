import type { ComponentType, ReactNode } from "react";
import { RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";

type Props = {
  icon?: ComponentType<{ className?: string }>;
  title: string;
  description?: ReactNode;
  /** Rendu si l'utilisateur a des filtres actifs → propose de les réinitialiser. */
  onReset?: () => void;
  /** CTA principal (ex: "Nouvel élément"). Ignoré si `onReset` est fourni. */
  action?: ReactNode;
  className?: string;
};

/**
 * État vide contextuel pour listes/tables :
 *
 * - filtres actifs → texte "aucun résultat" + bouton Réinitialiser
 * - liste vraiment vide → texte "aucune donnée" + CTA de création
 */
export function EmptyState({
  icon: Icon,
  title,
  description,
  onReset,
  action,
  className,
}: Props) {
  return (
    <div
      className={
        "flex flex-col items-center justify-center gap-3 rounded-lg border border-dashed py-10 text-center " +
        (className ?? "")
      }
    >
      {Icon ? <Icon className="h-10 w-10 text-muted-foreground/60" aria-hidden /> : null}
      <div className="space-y-1">
        <p className="text-sm font-medium">{title}</p>
        {description ? (
          <p className="text-xs text-muted-foreground">{description}</p>
        ) : null}
      </div>
      {onReset ? (
        <Button type="button" variant="outline" size="sm" onClick={onReset} className="gap-1">
          <RotateCcw className="h-3 w-3" />
          Réinitialiser les filtres
        </Button>
      ) : (
        action ?? null
      )}
    </div>
  );
}