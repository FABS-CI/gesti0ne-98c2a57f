import { RefreshCw } from "lucide-react";
import { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { usePullToRefresh } from "@/hooks/use-pull-to-refresh";
import { useIsMobile } from "@/hooks/use-mobile";

type Props = {
  onRefresh: () => void | Promise<void>;
  children: ReactNode;
  className?: string;
  /** Force l'activation même sur desktop */
  enabled?: boolean;
};

/**
 * Wrapper pull-to-refresh.
 * Actif uniquement sur mobile par défaut. Le conteneur devient le scroller.
 */
export function PullToRefresh({ onRefresh, children, className, enabled }: Props) {
  const isMobile = useIsMobile();
  const active = enabled ?? isMobile;
  const { containerRef, pullDistance, isRefreshing, progress } = usePullToRefresh({
    onRefresh,
    disabled: !active,
  });

  return (
    <div
      ref={containerRef}
      className={cn("relative overflow-y-auto overscroll-y-contain", className)}
    >
      {active && (pullDistance > 0 || isRefreshing) && (
        <div
          className="pointer-events-none absolute inset-x-0 top-0 z-10 flex items-center justify-center"
          style={{ height: pullDistance, transition: isRefreshing ? "height 150ms" : undefined }}
        >
          <RefreshCw
            className={cn(
              "h-5 w-5 text-muted-foreground",
              isRefreshing && "animate-spin"
            )}
            style={{
              transform: isRefreshing ? undefined : `rotate(${progress * 270}deg)`,
              opacity: Math.max(0.3, progress),
            }}
          />
        </div>
      )}
      <div
        style={{
          transform: `translateY(${pullDistance}px)`,
          transition: pullDistance === 0 || isRefreshing ? "transform 200ms" : undefined,
        }}
      >
        {children}
      </div>
    </div>
  );
}
