import { Link } from "@tanstack/react-router";
import {
  AlertTriangle,
  BadgeCheck,
  Boxes,
  Clock,
  FileText,
  Percent,
  Receipt,
  ShoppingCart,
  TrendingDown,
  TrendingUp,
  Truck,
  Users,
  Wallet,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatFCFA, formatFCFACompact } from "@/lib/format";
import type { DashboardOverview } from "@/hooks/use-dashboard-overview";

interface Props {
  data: DashboardOverview | undefined;
  canSeeCA: boolean;
}

export function DashboardKpis({ data, canSeeCA }: Props) {
  const allKpis = [
    {
      label: "Clients",
      value: data?.clientsTotal ?? 0,
      icon: Users,
      color: "#F97316",
      to: "/clients" as const,
      sensitive: false,
      tone: "neutral" as const,
    },
    {
      label: "Clients actifs",
      value: data?.clientsActifs ?? 0,
      icon: BadgeCheck,
      color: "#10B981",
      to: "/clients" as const,
      sensitive: false,
      tone: "success" as const,
    },
    {
      label: "Commandes",
      value: data?.nbCommandes ?? 0,
      icon: ShoppingCart,
      color: "#3B82F6",
      to: "/commandes" as const,
      sensitive: false,
      tone: "neutral" as const,
    },
    {
      label: "Chiffre d'affaires (encaissé)",
      value: canSeeCA ? formatFCFACompact(data?.caTotal ?? 0) : "—",
      icon: Wallet,
      color: "#14B8A6",
      to: "/paiements" as const,
      sensitive: true,
      tone: "highlight" as const,
    },
    {
      label: "Montant facturé",
      value: canSeeCA ? formatFCFACompact(data?.montantFacture ?? 0) : "—",
      icon: FileText,
      color: "#6366F1",
      to: "/factures" as const,
      sensitive: true,
      tone: "neutral" as const,
    },
    {
      label: "Reste à encaisser",
      value: canSeeCA ? formatFCFACompact(data?.resteAEncaisser ?? 0) : "—",
      icon: Receipt,
      color: "#F59E0B",
      to: "/factures" as const,
      sensitive: true,
      tone: (data?.resteAEncaisser ?? 0) > 0 ? ("warn" as const) : ("neutral" as const),
    },
    {
      label: "Taux d'encaissement",
      value: canSeeCA ? `${(data?.tauxEncaissement ?? 0).toFixed(1)}%` : "—",
      icon: Percent,
      color: "#10B981",
      to: "/paiements" as const,
      sensitive: true,
      tone: "success" as const,
    },
    {
      label: "Encours clients",
      value: formatFCFACompact(data?.soldeTotal ?? 0),
      icon: Wallet,
      color: "#0EA5E9",
      to: "/clients" as const,
      sensitive: true,
      tone: "neutral" as const,
    },
    {
      label: "Stock bas",
      value: data?.nbStockBas ?? 0,
      icon: Boxes,
      color: "#EAB308",
      to: "/stock" as const,
      sensitive: false,
      tone: (data?.nbStockBas ?? 0) > 0 ? ("warn" as const) : ("neutral" as const),
    },
    {
      label: "Factures en retard",
      value: data?.nbRetards ?? 0,
      icon: Clock,
      color: "#EF4444",
      to: "/factures" as const,
      sensitive: false,
      tone: (data?.nbRetards ?? 0) > 0 ? ("danger" as const) : ("neutral" as const),
    },
    {
      label: "Montant en retard",
      value: formatFCFACompact(data?.montantRetard ?? 0),
      icon: AlertTriangle,
      color: "#DC2626",
      to: "/factures" as const,
      sensitive: true,
      tone: (data?.montantRetard ?? 0) > 0 ? ("danger" as const) : ("neutral" as const),
    },
    {
      label: "Frais de tournée",
      value: formatFCFACompact(data?.fraisTournees ?? 0),
      icon: Truck,
      color: "#8B5CF6",
      to: "/tournees" as const,
      sensitive: false,
      tone: "neutral" as const,
    },
  ];
  const kpis = canSeeCA ? allKpis : allKpis.filter((k) => !k.sensitive);

  const finance = [
    {
      label: "Recettes",
      value: data?.recettes ?? 0,
      icon: TrendingUp,
      color: "#10B981",
      to: "/comptabilite" as const,
    },
    {
      label: "Dépenses",
      value: data?.depenses ?? 0,
      icon: TrendingDown,
      color: "#EF4444",
      to: "/comptabilite" as const,
    },
    {
      label: "Solde",
      value: data?.solde ?? 0,
      icon: Wallet,
      color: "#14B8A6",
      to: "/comptabilite" as const,
    },
  ];

  const toneClass = (tone: "neutral" | "success" | "warn" | "danger" | "highlight") => {
    switch (tone) {
      case "danger":
        return "border-red-500/40 bg-gradient-to-br from-red-500/5 to-transparent";
      case "warn":
        return "border-amber-500/40 bg-gradient-to-br from-amber-500/5 to-transparent";
      case "success":
        return "border-emerald-500/30 bg-gradient-to-br from-emerald-500/5 to-transparent";
      case "highlight":
        return "border-primary/40 bg-gradient-to-br from-primary/5 to-transparent";
      default:
        return "";
    }
  };

  return (
    <>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {kpis.map((k) => (
          <Link key={k.label} to={k.to} className="group">
            <Card
              className={`relative h-full overflow-hidden transition-all duration-200 hover:-translate-y-0.5 hover:shadow-lg group-hover:border-primary ${toneClass(k.tone)}`}
            >
              <span
                aria-hidden
                className="absolute inset-y-0 left-0 w-1"
                style={{ backgroundColor: k.color }}
              />
              <CardHeader className="flex flex-row items-center justify-between pb-2 pl-5">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {k.label}
                </CardTitle>
                <span
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-white shadow-sm transition-transform group-hover:scale-110"
                  style={{ backgroundColor: k.color }}
                >
                  <k.icon className="h-4 w-4" />
                </span>
              </CardHeader>
              <CardContent className="pl-5">
                <p
                  className={`text-2xl font-bold tracking-tight ${k.tone === "danger" ? "text-red-600 dark:text-red-400" : ""}`}
                >
                  {k.value}
                </p>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      {canSeeCA && (
      <div className="grid gap-4 sm:grid-cols-3">
        {finance.map((f) => (
          <Link key={f.label} to={f.to} className="group">
            <Card className="relative h-full overflow-hidden transition-all duration-200 hover:-translate-y-0.5 hover:shadow-lg group-hover:border-primary">
              <span
                aria-hidden
                className="absolute inset-y-0 left-0 w-1"
                style={{ backgroundColor: f.color }}
              />
              <CardHeader className="flex flex-row items-center justify-between pb-2 pl-5">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {f.label}
                </CardTitle>
                <span
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-white shadow-sm transition-transform group-hover:scale-110"
                  style={{ backgroundColor: f.color }}
                >
                  <f.icon className="h-4 w-4" />
                </span>
              </CardHeader>
              <CardContent className="pl-5">
                <p className="text-xl font-bold tracking-tight" style={{ color: f.color }}>
                  {formatFCFA(f.value)}
                </p>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>
      )}
    </>
  );
}
