import { useRef, type ReactNode } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";

/**
 * Liste virtualisée générique (Lot 2 perf).
 *
 * À utiliser pour toute liste > 200 éléments non paginée serveur.
 * Ne rend que les items visibles → scroll fluide même à 10 000 lignes.
 *
 * Contraintes :
 * - Le conteneur doit avoir une hauteur fixe (`height` obligatoire).
 * - Passer une `estimateSize` réaliste pour éviter les recalculs excessifs.
 *
 * Exemple :
 *   <VirtualList
 *     items={notifications}
 *     height={600}
 *     estimateSize={72}
 *     getKey={(n) => n.id}
 *     renderItem={(n) => <NotificationRow n={n} />}
 *   />
 */
export function VirtualList<T>({
  items,
  height,
  estimateSize,
  overscan = 8,
  getKey,
  renderItem,
  className,
}: {
  items: T[];
  height: number;
  estimateSize: number;
  overscan?: number;
  getKey: (item: T, index: number) => string | number;
  renderItem: (item: T, index: number) => ReactNode;
  className?: string;
}) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => estimateSize,
    overscan,
  });

  return (
    <div
      ref={parentRef}
      className={className}
      style={{ height, overflow: "auto", contain: "strict" }}
    >
      <div
        style={{
          height: virtualizer.getTotalSize(),
          width: "100%",
          position: "relative",
        }}
      >
        {virtualizer.getVirtualItems().map((v) => {
          const item = items[v.index];
          return (
            <div
              key={getKey(item, v.index)}
              data-index={v.index}
              ref={virtualizer.measureElement}
              style={{
                position: "absolute",
                top: 0,
                left: 0,
                width: "100%",
                transform: `translateY(${v.start}px)`,
              }}
            >
              {renderItem(item, v.index)}
            </div>
          );
        })}
      </div>
    </div>
  );
}
