import { useEffect, useRef, useState } from "react";

type Options = {
  onRefresh: () => void | Promise<void>;
  /** Distance en px pour déclencher le refresh */
  threshold?: number;
  /** Distance max de tirage (résistance) */
  maxPull?: number;
  /** Désactiver (ex: desktop) */
  disabled?: boolean;
};

/**
 * Hook pull-to-refresh pour mobile.
 * À attacher sur un conteneur scrollable (ou window par défaut).
 *
 * Retourne :
 *  - containerRef : à poser sur l'élément scrollable
 *  - pullDistance : distance actuelle du tirage (px)
 *  - isRefreshing : true pendant l'exécution de onRefresh
 *  - progress : 0 → 1 (ratio par rapport au threshold)
 */
export function usePullToRefresh({
  onRefresh,
  threshold = 70,
  maxPull = 120,
  disabled = false,
}: Options) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const startY = useRef<number | null>(null);
  const pulling = useRef(false);
  const [pullDistance, setPullDistance] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    if (disabled) return;
    const el = containerRef.current;
    if (!el) return;

    const getScrollTop = () => el.scrollTop;

    const onTouchStart = (e: TouchEvent) => {
      if (isRefreshing) return;
      if (getScrollTop() > 0) {
        startY.current = null;
        return;
      }
      startY.current = e.touches[0].clientY;
      pulling.current = false;
    };

    const onTouchMove = (e: TouchEvent) => {
      if (startY.current == null || isRefreshing) return;
      const dy = e.touches[0].clientY - startY.current;
      if (dy <= 0) {
        setPullDistance(0);
        pulling.current = false;
        return;
      }
      if (getScrollTop() > 0) {
        setPullDistance(0);
        pulling.current = false;
        return;
      }
      pulling.current = true;
      // résistance : sqrt pour un effet élastique
      const resisted = Math.min(maxPull, Math.sqrt(dy) * 8);
      setPullDistance(resisted);
      if (e.cancelable) e.preventDefault();
    };

    const onTouchEnd = async () => {
      if (!pulling.current) {
        setPullDistance(0);
        startY.current = null;
        return;
      }
      const shouldRefresh = pullDistance >= threshold;
      pulling.current = false;
      startY.current = null;

      if (shouldRefresh) {
        setIsRefreshing(true);
        setPullDistance(threshold);
        try {
          await onRefresh();
        } finally {
          setIsRefreshing(false);
          setPullDistance(0);
        }
      } else {
        setPullDistance(0);
      }
    };

    el.addEventListener("touchstart", onTouchStart, { passive: true });
    el.addEventListener("touchmove", onTouchMove, { passive: false });
    el.addEventListener("touchend", onTouchEnd, { passive: true });
    el.addEventListener("touchcancel", onTouchEnd, { passive: true });

    return () => {
      el.removeEventListener("touchstart", onTouchStart);
      el.removeEventListener("touchmove", onTouchMove);
      el.removeEventListener("touchend", onTouchEnd);
      el.removeEventListener("touchcancel", onTouchEnd);
    };
  }, [disabled, isRefreshing, maxPull, onRefresh, pullDistance, threshold]);

  return {
    containerRef,
    pullDistance,
    isRefreshing,
    progress: Math.min(1, pullDistance / threshold),
  };
}
