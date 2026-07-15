import { AlertTriangle, CheckCircle2, Clock, Send, XCircle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { STATUT_FNE_COLOR, STATUT_FNE_LABEL, type FNEStatus } from "@/lib/fne-api";

export function FneStatusBadge({ statut }: { statut: string }) {
  const s = (statut as FNEStatus) ?? "pending";
  const Icon =
    s === "accepted"
      ? CheckCircle2
      : s === "submitted"
        ? Send
        : s === "pending"
          ? Clock
          : s === "rejected"
            ? XCircle
            : AlertTriangle;
  return (
    <Badge
      style={{ backgroundColor: STATUT_FNE_COLOR[s] ?? "#999", color: "#fff" }}
      className="gap-1"
    >
      <Icon className="h-3 w-3" />
      {STATUT_FNE_LABEL[s] ?? s}
    </Badge>
  );
}
