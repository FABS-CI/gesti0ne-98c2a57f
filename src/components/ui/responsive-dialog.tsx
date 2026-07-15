import type { ReactNode } from "react";
import { useIsMobile } from "@/hooks/use-mobile";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { cn } from "@/lib/utils";

/**
 * Wrapper adaptatif :
 * - Sur mobile (<768px) : bottom sheet plein largeur, hauteur max 90dvh, scroll interne,
 *   footer collé en bas (au-dessus du clavier grâce à --keyboard-height).
 * - Sur desktop : Dialog centré classique.
 *
 * Idéal pour les formulaires longs (création facture, commande, employé, etc.).
 * L'API imite <Dialog> shadcn — remplacer `Dialog` par `ResponsiveDialog` suffit.
 */
export function ResponsiveDialog({
  open,
  onOpenChange,
  title,
  description,
  children,
  footer,
  className,
  contentClassName,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title?: ReactNode;
  description?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  className?: string;
  contentClassName?: string;
}) {
  const isMobile = useIsMobile();

  if (isMobile) {
    return (
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent
          side="bottom"
          className={cn(
            "flex max-h-[90dvh] flex-col gap-0 rounded-t-2xl p-0",
            "pb-[env(safe-area-inset-bottom)]",
            className,
          )}
        >
          {(title || description) && (
            <SheetHeader className="border-b px-4 py-3 text-left">
              {title && <SheetTitle>{title}</SheetTitle>}
              {description && <SheetDescription>{description}</SheetDescription>}
            </SheetHeader>
          )}
          <div
            className={cn(
              "min-h-0 flex-1 overflow-y-auto px-4 py-4",
              contentClassName,
            )}
            style={{ paddingBottom: "calc(1rem + var(--keyboard-height, 0px))" }}
          >
            {children}
          </div>
          {footer && (
            <SheetFooter className="sticky bottom-0 border-t bg-background px-4 py-3">
              {footer}
            </SheetFooter>
          )}
        </SheetContent>
      </Sheet>
    );
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className={cn("max-h-[85vh] gap-0 overflow-hidden p-0", className)}>
        {(title || description) && (
          <DialogHeader className="border-b px-6 py-4">
            {title && <DialogTitle>{title}</DialogTitle>}
            {description && <DialogDescription>{description}</DialogDescription>}
          </DialogHeader>
        )}
        <div className={cn("max-h-[65vh] overflow-y-auto px-6 py-4", contentClassName)}>
          {children}
        </div>
        {footer && (
          <DialogFooter className="border-t px-6 py-3">{footer}</DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  );
}
