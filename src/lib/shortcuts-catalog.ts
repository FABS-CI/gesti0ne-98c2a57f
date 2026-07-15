import type { LucideIcon } from "lucide-react";
import {
  ShoppingCart,
  UserPlus,
  CreditCard,
  FileText,
  FileSpreadsheet,
  Truck,
  Package,
  PackageCheck,
  Boxes,
  MapPin,
  Users,
  Wallet,
  Warehouse,
  Building2,
  Car,
  Handshake,
} from "lucide-react";

export interface ShortcutDef {
  key: string;
  module: string;
  label: string;
  icon: LucideIcon;
  iconName: string;
  href: string;
  permission?: string;
}

export const SHORTCUTS_CATALOG: ShortcutDef[] = [
  {
    key: "commandes.create",
    module: "commercial",
    label: "Nouvelle commande",
    icon: ShoppingCart,
    iconName: "ShoppingCart",
    href: "/commandes/nouvelle",
    permission: "commandes.creer",
  },
  {
    key: "clients.create",
    module: "crm",
    label: "Nouveau client",
    icon: UserPlus,
    iconName: "UserPlus",
    href: "/clients",
    permission: "clients.creer",
  },
  {
    key: "paiements.create",
    module: "finance",
    label: "Nouveau paiement",
    icon: CreditCard,
    iconName: "CreditCard",
    href: "/paiements/nouveau",
    permission: "paiements.creer",
  },
  {
    key: "factures.create",
    module: "finance",
    label: "Nouvelle facture",
    icon: FileText,
    iconName: "FileText",
    href: "/factures",
    permission: "factures.creer",
  },
  {
    key: "devis.create",
    module: "commercial",
    label: "Nouveau devis",
    icon: FileSpreadsheet,
    iconName: "FileSpreadsheet",
    href: "/proformas",
    permission: "proformas.creer",
  },
  {
    key: "colisage.create",
    module: "logistique",
    label: "Nouveau colisage",
    icon: Package,
    iconName: "Package",
    href: "/colisage",
    permission: "colisage.creer",
  },
  {
    key: "reception.create",
    module: "stock",
    label: "Nouveau bon de réception",
    icon: PackageCheck,
    iconName: "PackageCheck",
    href: "/achats/nouveau",
    permission: "achats.creer",
  },
  {
    key: "articles.create",
    module: "stock",
    label: "Nouvel article",
    icon: Boxes,
    iconName: "Boxes",
    href: "/produits",
    permission: "produits.creer",
  },
  {
    key: "tournees.create",
    module: "logistique",
    label: "Nouvelle tournée",
    icon: MapPin,
    iconName: "MapPin",
    href: "/tournees",
    permission: "tournees.creer",
  },
];

export const MODULE_META: Record<string, { label: string; icon: LucideIcon; href: string }> = {
  commercial: { label: "Commercial", icon: Handshake, href: "/commandes" },
  finance: { label: "Finance", icon: Wallet, href: "/comptabilite" },
  stock: { label: "Stock", icon: Warehouse, href: "/produits" },
  logistique: { label: "Logistique", icon: Truck, href: "/livraisons" },
  crm: { label: "CRM", icon: Users, href: "/clients" },
  rh: { label: "Ressources humaines", icon: Building2, href: "/employes" },
  flotte: { label: "Flotte", icon: Car, href: "/vehicules" },
};

export function findShortcut(key: string): ShortcutDef | undefined {
  return SHORTCUTS_CATALOG.find((s) => s.key === key);
}
