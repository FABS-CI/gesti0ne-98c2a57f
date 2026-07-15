import { forwardRef, type CSSProperties, type HTMLAttributes, type ReactNode } from "react";
import { GripVertical } from "lucide-react";
import { useQuery } from "@tanstack/react-query";

import { WIDGETS, fetchAllWidgets, type WidgetId } from "@/lib/dashboard-widgets";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";

type Props = {
  id: WidgetId;
  editMode: boolean;
  dragHandle?: ReactNode;
  style?: CSSProperties;
  className?: string;
} & Omit<HTMLAttributes<HTMLDivElement>, "id" | "style" | "className">;

export const WidgetCard = forwardRef<HTMLDivElement, Props>(function WidgetCard(
  { id, editMode, dragHandle, style, className, ...rest },
  ref,
) {
  const def = WIDGETS[id];
  // Query partagée : tous les WidgetCard partagent la même queryKey, donc
  // React Query déduplique et un seul batch réseau est émis.
  const { data: all, isLoading } = useQuery({
    queryKey: ["dashboard-widgets-all"],
    queryFn: fetchAllWidgets,
    staleTime: 5 * 60_000,
    gcTime: 10 * 60_000,
  });
  const data = all?.[id];

  const Icon = def.icon;

  return (
    <Card ref={ref} style={style} className={className} {...rest}>
      <CardContent className="p-4">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-2">
            <Icon className={`h-5 w-5 ${def.accent}`} />
            <p className="text-sm font-medium">{def.title}</p>
          </div>
          {editMode &&
            (dragHandle ?? (
              <span className="text-muted-foreground">
                <GripVertical className="h-4 w-4" />
              </span>
            ))}
        </div>
        <div className="mt-3">
          {isLoading ? (
            <Skeleton className="h-8 w-24" />
          ) : (
            <>
              <p className="text-2xl font-semibold">{data?.value ?? "—"}</p>
              {data?.sub && (
                <Badge variant="secondary" className="mt-1 text-xs font-normal">
                  {data.sub}
                </Badge>
              )}
            </>
          )}
        </div>
      </CardContent>
    </Card>
  );
});
