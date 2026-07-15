import { Link } from "@tanstack/react-router";
import {
  AlertTriangle,
  BadgeCheck,
  Boxes,
  Clock,
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
    },
    {
      label: "Clients actifs",
      value: data?.clientsActifs ?? 0,
      icon: BadgeCheck,
      color: "#10B981",
      to: "/clients" as const,
      sensitive: false,
    },
    {
      label: "Commandes",
      value: data?.nbCommandes ?? 0,
      icon: ShoppingCart,
      color: "#3B82F6",
      to: "/commandes" as const,
      sensitive: false,
    },
    {
      label: "Chiffre d'affaires",
      value: canSeeCA ? formatFCFACompact(data?.caTotal ?? 0) : "—",
      icon: Wallet,
      color: "#14B8A6",
      to: "/commandes" as const,
      sensitive: true,
    },
    {
      label: "Encours clients",
      value: formatFCFACompact(data?.soldeTotal ?? 0),
      icon: Wallet,
      color: "#0EA5E9",
      to: "/clients" as const,
      sensitive: true,
    },
    {
      label: "Stock bas",
      value: data?.nbStockBas ?? 0,
      icon: Boxes,
      color: "#EAB308",
      to: "/stock" as const,
      sensitive: false,
    },
    {
      label: "Factures en retard",
      value: data?.nbRetards ?? 0,
      icon: Clock,
      color: "#EF4444",
      to: "/factures" as const,
      sensitive: false,
    },
    {
      label: "Montant en retard",
      value: formatFCFACompact(data?.montantRetard ?? 0),
      icon: AlertTriangle,
      color: "#DC2626",
      to: "/factures" as const,
      sensitive: true,
    },
    {
      label: "Frais de tournée",
      value: formatFCFACompact(data?.fraisTournees ?? 0),
      icon: Truck,
      color: "#8B5CF6",
      to: "/tournees" as const,
      sensitive: false,
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

  return (
    <>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {kpis.map((k) => (
          <Link key={k.label} to={k.to} className="group">
            <Card className="h-full transition-colors group-hover:border-primary">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {k.label}
                </CardTitle>
                <span
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-white"
                  style={{ backgroundColor: k.color }}
                >
                  <k.icon className="h-4 w-4" />
                </span>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-bold">{k.value}</p>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      {canSeeCA && (
      <div className="grid gap-4 sm:grid-cols-3">
        {finance.map((f) => (
          <Link key={f.label} to={f.to} className="group">
            <Card className="h-full transition-colors group-hover:border-primary">
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {f.label}
                </CardTitle>
                <span
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-white"
                  style={{ backgroundColor: f.color }}
                >
                  <f.icon className="h-4 w-4" />
                </span>
              </CardHeader>
              <CardContent>
                <p className="text-xl font-bold" style={{ color: f.color }}>
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
