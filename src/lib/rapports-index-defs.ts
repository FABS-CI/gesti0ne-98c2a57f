import {
  Users,
  ShoppingCart,
  Package,
  Wallet,
  FileText,
  CreditCard,
  Truck,
  UserCog,
  Factory,
  Warehouse,
  ClipboardList,
  FileSpreadsheet,
  Receipt,
  BookOpen,
  Banknote,
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import type { ReportDef } from "./rapports-index-helpers";

export const REPORTS: ReportDef[] = [
  {
    table: "clients",
    permission: "rapports.voir_ca",
    label: "Liste des Clients",
    description: "Annuaire clients groupé par ville",
    icon: Users,
    color: "#3B82F6",
    columns: [
      { key: "nom", label: "Client" },
      { key: "telephone", label: "Téléphone" },
      { key: "representant", label: "Représentant" },
      { key: "email", label: "Email" },
      { key: "type_client", label: "Type" },
      { key: "plafond_credit", label: "Plafond", money: true },
      { key: "solde", label: "Solde dû", money: true },
    ],
    fetcher: async () => {
      const { data, error } = await supabase
        .from("clients")
        .select(
          "nom, telephone, representant, email, type_client, ville, plafond_credit, solde",
        )
        .order("ville", { ascending: true })
        .order("nom", { ascending: true })
        .range(0, 9999);
      if (error) throw error;
      const rows = (data ?? []) as Array<Record<string, unknown>>;
      const out: Array<Record<string, unknown>> = [];
      let current = "__INIT__";
      for (const r of rows) {
        const v = (r.ville as string) || "—";
        if (v !== current) {
          out.push({ __group__: v.toUpperCase() });
          current = v;
        }
        out.push(r);
      }
      return out;
    },
  },

  {
    table: "commandes",
    permission: "rapports.voir_ca",
    label: "Commandes",
    description: "Toutes les commandes",
    icon: ShoppingCart,
    color: "#F97316",
    columns: [
      { key: "reference", label: "Référence" },
      { key: "date_commande", label: "Date", date: true },
      { key: "client_nom", label: "Client" },
      { key: "statut", label: "Statut" },
      { key: "montant_total", label: "Montant", money: true },
    ],
  },
  {
    table: "produits",
    label: "Produits",
    description: "Catalogue produits & stock",
    icon: Package,
    color: "#10B981",
    columns: [
      { key: "reference", label: "Code Article" },
      { key: "isbn", label: "ISBN" },
      { key: "titre", label: "Désignation" },
      { key: "categorie", label: "Catégorie" },
      { key: "niveau", label: "Niveau" },
      { key: "matiere", label: "Matière" },
      { key: "prix_vente", label: "Prix vente", money: true },
      { key: "stock", label: "Stock" },
      { key: "seuil_alerte", label: "Seuil" },
    ],
    fetcher: async () => {
      const { data, error } = await supabase
        .from("v_produits")
        .select(
          "reference, isbn, titre, categorie, niveau, matiere, editeur, prix_achat, prix_vente, stock, seuil_alerte",
        )
        .order("pin_order", { ascending: true })
        .order("niveau_ordre", { ascending: true })
        .order("titre", { ascending: true });
      if (error) throw error;
      return (data ?? []) as Record<string, unknown>[];
    },
  },
  {
    table: "transactions",
    permission: "rapports.voir_ca",
    label: "Comptabilité",
    description: "Recettes et dépenses",
    icon: Wallet,
    color: "#8B5CF6",
    columns: [
      { key: "reference", label: "Réf." },
      { key: "date_transaction", label: "Date", date: true },
      { key: "type", label: "Type" },
      { key: "categorie", label: "Catégorie" },
      { key: "libelle", label: "Libellé" },
      { key: "montant", label: "Montant", money: true },
    ],
  },
  {
    table: "factures",
    permission: "rapports.voir_ca",
    label: "Factures",
    description: "Facturation clients",
    icon: FileText,
    color: "#EF4444",
    columns: [
      { key: "reference", label: "Référence" },
      { key: "date_facture", label: "Date", date: true },
      { key: "date_echeance", label: "Échéance", date: true },
      { key: "client_nom", label: "Client" },
      { key: "statut", label: "Statut" },
      { key: "montant_total", label: "Montant", money: true },
    ],
  },
  {
    table: "paiements",
    permission: "rapports.voir_ca",
    label: "Paiements",
    description: "Encaissements",
    icon: CreditCard,
    color: "#14B8A6",
    columns: [
      { key: "reference", label: "Référence" },
      { key: "date_paiement", label: "Date", date: true },
      { key: "client_nom", label: "Client" },
      { key: "mode_paiement", label: "Mode" },
      { key: "montant", label: "Montant", money: true },
    ],
  },
  {
    table: "achats",
    permission: "rapports.voir_ca",
    label: "Achats",
    description: "Bons de commande fournisseurs",
    icon: Truck,
    color: "#F59E0B",
    columns: [
      { key: "reference", label: "Référence" },
      { key: "date_achat", label: "Date", date: true },
      { key: "fournisseur_nom", label: "Fournisseur" },
      { key: "statut", label: "Statut" },
      { key: "montant_total", label: "Montant", money: true },
    ],
  },
  {
    table: "employes",
    label: "Employés",
    description: "Registre du personnel",
    icon: UserCog,
    color: "#6366F1",
    columns: [
      { key: "matricule", label: "Matricule" },
      { key: "nom_complet", label: "Nom complet" },
      { key: "poste", label: "Poste" },
      { key: "departement", label: "Département" },
      { key: "telephone", label: "Téléphone" },
      { key: "email", label: "Email" },
      { key: "date_embauche", label: "Embauche", date: true },
    ],
  },
  {
    table: "fournisseurs",
    label: "Fournisseurs",
    description: "Annuaire des fournisseurs",
    icon: Factory,
    color: "#0EA5E9",
    columns: [
      { key: "raison_sociale", label: "Raison sociale" },
      { key: "contact", label: "Contact" },
      { key: "telephone", label: "Téléphone" },
      { key: "email", label: "Email" },
      { key: "ville", label: "Ville" },
      { key: "adresse", label: "Adresse" },
      { key: "actif", label: "Actif" },
    ],
  },
  {
    table: "proformas",
    permission: "rapports.voir_ca",
    label: "Devis / Proformas",
    description: "Devis et proformas émis",
    icon: FileSpreadsheet,
    color: "#A855F7",
    columns: [
      { key: "reference", label: "Référence" },
      { key: "date_proforma", label: "Date", date: true },
      { key: "date_validite", label: "Validité", date: true },
      { key: "client_nom", label: "Client" },
      { key: "statut", label: "Statut" },
      { key: "montant_total", label: "Montant", money: true },
    ],
  },
  {
    table: "bons_livraison",
    label: "Bons de livraison",
    description: "BL émis",
    icon: Truck,
    color: "#22C55E",
    columns: [
      { key: "reference", label: "Référence" },
      { key: "date_emission", label: "Émission", date: true },
      { key: "date_livraison", label: "Livraison", date: true },
      { key: "transporteur", label: "Transporteur" },
      { key: "statut", label: "Statut" },
      { key: "montant_total", label: "Montant", money: true },
    ],
  },
  {
    table: "stocks_depots",
    label: "Stocks",
    description: "Niveaux de stock par dépôt",
    icon: Warehouse,
    color: "#0D9488",
    columns: [
      { key: "produit_id", label: "Produit" },
      { key: "depot_id", label: "Dépôt" },
      { key: "quantite", label: "Quantité" },
      { key: "updated_at", label: "Mis à jour", date: true },
    ],
  },
  {
    table: "inventaires",
    label: "Inventaires",
    description: "Inventaires physiques",
    icon: ClipboardList,
    color: "#D97706",
    columns: [
      { key: "numero", label: "Numéro" },
      { key: "type_inventaire", label: "Type" },
      { key: "date_inventaire", label: "Date", date: true },
      { key: "nb_produits", label: "Produits" },
      { key: "nb_ecarts", label: "Écarts" },
      { key: "valeur_totale", label: "Valeur", money: true },
      { key: "statut", label: "Statut" },
    ],
  },
  {
    table: "etat_compte",
    permission: "rapports.voir_ca",
    label: "État de compte clients",
    description: "Solde par client (factures)",
    icon: Receipt,
    color: "#DC2626",
    columns: [
      { key: "client_nom", label: "Client" },
      { key: "nb_factures", label: "Nb factures" },
      { key: "total_facture", label: "Total facturé", money: true },
      { key: "total_paye", label: "Total payé", money: true },
      { key: "solde", label: "Solde dû", money: true },
    ],
    fetcher: async (exerciceId) => {
      let q = supabase.from("factures").select("client_nom, montant_total, montant_paye");
      if (exerciceId) q = q.eq("exercice_id", exerciceId);
      const { data, error } = await q;
      if (error) throw error;
      const map = new Map<string, { nb: number; tot: number; paye: number }>();
      for (const f of (data ?? []) as Array<{
        client_nom: string | null;
        montant_total: number | null;
        montant_paye: number | null;
      }>) {
        const k = f.client_nom ?? "—";
        const cur = map.get(k) ?? { nb: 0, tot: 0, paye: 0 };
        cur.nb += 1;
        cur.tot += Number(f.montant_total ?? 0);
        cur.paye += Number(f.montant_paye ?? 0);
        map.set(k, cur);
      }
      return Array.from(map.entries())
        .map(([client_nom, v]) => ({
          client_nom,
          nb_factures: v.nb,
          total_facture: v.tot,
          total_paye: v.paye,
          solde: v.tot - v.paye,
        }))
        .sort((a, b) => b.solde - a.solde);
    },
  },
  {
    table: "ecritures_comptables",
    permission: "rapports.voir_ca",
    label: "Comptabilité",
    description: "Écritures comptables",
    icon: BookOpen,
    color: "#7C3AED",
    columns: [
      { key: "reference", label: "Référence" },
      { key: "date_ecriture", label: "Date", date: true },
      { key: "journal", label: "Journal" },
      { key: "libelle", label: "Libellé" },
      { key: "lettrage", label: "Lettrage" },
      { key: "montant_total", label: "Montant", money: true },
    ],
  },
  {
    table: "bulletins_paie",
    permission: "rapports.voir_ca",
    label: "Bulletins de paie",
    description: "Bulletins RH",
    icon: Banknote,
    color: "#EC4899",
    columns: [
      { key: "employe_nom", label: "Employé" },
      { key: "periode", label: "Période" },
      { key: "salaire_brut", label: "Brut", money: true },
      { key: "retenues", label: "Retenues", money: true },
      { key: "salaire_net", label: "Net", money: true },
      { key: "statut", label: "Statut" },
    ],
  },
];
