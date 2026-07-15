import { useRef, type ReactNode } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";

/**
 * Wrapper virtualisation de lignes pour les listes de plus de ~100 items.
 * Rend uniquement les lignes visibles + un overscan de 8.
 *
 * Utilisation :
 *   <VirtualTable rowCount={items.length} rowHeight={44} height={600}>
 *     {(index) => <TableRow>...items[index]...</TableRow>}
 *   </VirtualTable>
 *
 * Pour rester compatible avec les tables shadcn existantes, on rend un
 * <div> scrollable qui contient un <table> full-width. À utiliser dans les
 * détails/historique où on ne peut pas paginer côté serveur.
 */
export function VirtualTable({
  rowCount,
  rowHeight = 44,
  height = 600,
  overscan = 8,
  header,
  children,
}: {
  rowCount: number;
  rowHeight?: number;
  height?: number;
  overscan?: number;
  header?: ReactNode;
  children: (index: number) => ReactNode;
}) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: rowCount,
    getScrollElement: () => parentRef.current,
    estimateSize: () => rowHeight,
    overscan,
  });

  return (
    <div
      ref={parentRef}
      className="overflow-auto rounded-lg border"
      style={{ height, contain: "strict" }}
    >
      {header}
      <div
        style={{
          height: virtualizer.getTotalSize(),
          width: "100%",
          position: "relative",
        }}
      >
        {virtualizer.getVirtualItems().map((v) => (
          <div
            key={v.key}
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
            {children(v.index)}
          </div>
        ))}
      </div>
    </div>
  );
}
