import type { AppRole } from "@/hooks/use-user-roles";

/**
 * Matrice officielle FABS-CI V10 (rôles × modules).
 * - `super_admin` a toujours accès (court-circuit dans canAccess).
 * - `undefined` ou tableau vide = accessible à tout staff connecté.
 * - Une route absente est, par défaut, accessible à tout staff (Notifications,
 *   Profil, etc.).
 */
export const ROUTE_PERMISSIONS: Record<string, AppRole[] | undefined> = {
  // ===== Tableaux de bord =====
  "/dashboard": [
    "directeur_general",
    "comptable",
    "directeur_commercial",
    "gestionnaire_stock",
    "responsable_magasinier",
    "secretariat",
    "service_logistique",
  ],
  "/mon-dashboard": [
    "directeur_general",
    "comptable",
    "directeur_commercial",
    "gestionnaire_stock",
    "responsable_magasinier",
    "secretariat",
    "service_logistique",
  ],
  "/dashboard-global": [], // super_admin uniquement (BI)
  "/bi-analytics": [], // super_admin uniquement
  "/rapports": ["comptable"],

  // ===== Gestion commerciale =====
  "/clients": ["comptable", "directeur_commercial", "secretariat", "assistante"],
  "/commandes": [
    "comptable",
    "directeur_commercial",
    "responsable_magasinier",
    "secretariat",
    "assistante",
  ],
  "/commandes/nouvelle": ["comptable", "directeur_commercial", "secretariat", "assistante"],
  "/commandes/$commandeId": [
    "comptable",
    "directeur_commercial",
    "responsable_magasinier",
    "secretariat",
    "assistante",
  ],
  "/commandes/$commandeId/modifier": [
    "directeur_general",
    "comptable",
    "directeur_commercial",
    "secretariat",
  ],
  "/proformas": ["comptable", "secretariat", "assistante"],
  "/factures": ["comptable"],
  "/paiements": ["directeur_general", "comptable"],
  "/paiements/nouveau": ["directeur_general", "comptable"],
  "/livraison-suivi": ["directeur_commercial", "service_logistique"],
  "/bons-livraison": ["directeur_general", "comptable", "service_logistique"],
  "/retours": ["gestionnaire_stock"],
  "/specimens": [
    "gestionnaire_stock",
    "responsable_magasinier",
    "directeur_general",
    "directeur_commercial",
  ],
  "/colis": ["responsable_magasinier", "service_logistique"],
  "/expeditions": ["service_logistique"],
  "/historique-envois": ["service_logistique"],

  // ===== Stocks & logistique =====
  "/produits": ["comptable", "gestionnaire_stock", "secretariat", "assistante"],
  "/inventaires": ["gestionnaire_stock", "responsable_magasinier", "comptable"],
  "/inventaires/nouveau-physique": ["gestionnaire_stock", "responsable_magasinier"],
  "/inventaires/$inventaireId": ["gestionnaire_stock", "responsable_magasinier", "comptable"],

  "/catalogue-integrite": [],
  "/stock": ["gestionnaire_stock", "responsable_magasinier"],
  "/depots": ["gestionnaire_stock", "responsable_magasinier"],
  "/transferts": ["gestionnaire_stock", "responsable_magasinier", "service_logistique"],
  "/ordres-colisage": ["responsable_magasinier"],
  "/incidents": ["gestionnaire_stock", "responsable_magasinier", "service_logistique"],
  "/incidents/nouveau": ["gestionnaire_stock", "responsable_magasinier", "service_logistique"],
  "/incidents/$incidentId": ["gestionnaire_stock", "responsable_magasinier", "service_logistique"],
  "/fleet": ["service_logistique"],
  "/logistics-costs": ["comptable", "service_logistique"],
  "/tournees": ["service_logistique", "comptable"],
  "/bon-de-sortie": ["service_logistique", "comptable"],
  "/bon-de-tournee": ["service_logistique", "comptable"],
  "/tournees-bl": ["service_logistique", "comptable"],
  "/dashboard-logistique": ["service_logistique", "comptable"],
  "/rapports-logistique": ["service_logistique", "comptable"],
  "/fournisseurs": ["gestionnaire_stock"],
  "/achats": ["gestionnaire_stock"],
  "/colisage": ["gestionnaire_stock", "responsable_magasinier", "service_logistique"],

  // ===== Finances =====
  "/etat-compte-clients": ["comptable", "secretariat"],
  "/comptabilite": ["comptable"],
  "/compta-dashboard": ["comptable"],
  "/balance": ["comptable"],
  "/grand-livre": ["comptable"],
  "/fne": ["comptable"],
  "/fne-nouvelle": ["comptable"],
  "/fne-detail": ["comptable"],
  "/fne-logs": ["comptable"],
  "/fne-settings": ["comptable"],
  "/finances": ["directeur_general", "comptable"],

  // ===== Ressources humaines =====
  "/employes": ["directeur_general", "comptable", "secretariat"],
  "/departements": ["directeur_general", "comptable", "secretariat"],
  "/fonctions": ["directeur_general", "comptable", "secretariat"],
  "/contrats": ["directeur_general", "comptable", "secretariat"],
  "/conges": ["directeur_general", "comptable", "secretariat"],
  "/absences": ["directeur_general", "comptable", "secretariat"],
  "/missions": ["directeur_general", "comptable", "secretariat"],
  "/evaluations": ["directeur_general", "comptable"],
  "/rh-dashboard": ["directeur_general", "comptable"],
  "/paie": ["directeur_general", "comptable"],

  // ===== Administration & documents =====
  "/file-storage": [], // super_admin
  "/backup": [], // super_admin
  "/utilisateurs": [], // super_admin
  "/parametres": [], // super_admin
  "/documents-impression": [], // super_admin
  "/modeles-documents": [], // super_admin
  "/centre-documents": [], // super_admin
  "/audit": [], // super_admin
  "/roles-permissions": [], // super_admin
  "/import-donnees": [], // super_admin
  "/admin/sante-systeme": [], // super_admin uniquement

  "/exports": ["directeur_general", "comptable"],

  // Workflow approvals : super_admin + DG + comptable
  "/approbations": ["directeur_general", "comptable"],
  "/workflow-approvals": ["directeur_general", "comptable"],
  "/workflows-definitions": ["directeur_general"], // création workflow

  // Routes laissées ouvertes (tout staff) : /notifications, /profil
};

/**
 * Permissions granulaires (RBAC fin) — utilisées par les composants pour
 * masquer/afficher des boutons individuels au sein d'un écran déjà accessible.
 * Source : matrice officielle FABS-CI V10 §3.
 */
export type Permission =
  // Clients
  | "view_clients"
  | "create_clients"
  | "edit_clients"
  | "delete_clients"
  // Produits
  | "view_produits"
  | "create_produits"
  | "edit_produits"
  | "delete_produits"
  // Commandes
  | "view_commandes"
  | "create_commandes"
  | "edit_commandes"
  | "validate_commandes"
  // Factures
  | "view_factures"
  | "create_factures"
  | "edit_factures"
  | "validate_factures"
  // Paiements
  | "view_paiements"
  | "process_paiements"
  // Stock
  | "view_stock"
  | "edit_stock"
  // Rapports
  | "view_rapports"
  | "export_rapports"
  // Administration
  | "view_utilisateurs"
  | "manage_utilisateurs"
  | "admin_settings"
  | "audit_log";

export const PERMISSIONS: Record<Permission, AppRole[]> = {
  view_clients: ["directeur_general", "directeur_commercial", "comptable"],
  create_clients: ["directeur_general", "directeur_commercial"],
  edit_clients: ["directeur_general", "directeur_commercial"],
  delete_clients: [],

  view_produits: [
    "directeur_general",
    "directeur_commercial",
    "comptable",
    "responsable_magasinier",
    "gestionnaire_stock",
    "secretariat",
  ],
  create_produits: ["gestionnaire_stock"],
  edit_produits: ["gestionnaire_stock"],
  delete_produits: [],

  view_commandes: [
    "directeur_general",
    "directeur_commercial",
    "comptable",
    "responsable_magasinier",
    "secretariat",
    "assistante",
  ],
  create_commandes: ["directeur_commercial", "secretariat", "comptable"],
  edit_commandes: ["directeur_general", "directeur_commercial", "comptable"],
  validate_commandes: ["directeur_general", "comptable"],

  view_factures: ["directeur_commercial", "comptable"],
  create_factures: ["comptable"],
  edit_factures: ["comptable"],
  validate_factures: ["directeur_general", "comptable"],

  view_paiements: ["directeur_general", "comptable"],
  process_paiements: ["comptable"],

  view_stock: ["responsable_magasinier", "gestionnaire_stock"],
  edit_stock: ["gestionnaire_stock"],

  view_rapports: ["directeur_general", "comptable"],
  export_rapports: ["directeur_general", "comptable"],

  view_utilisateurs: [],
  manage_utilisateurs: [],
  admin_settings: [],
  audit_log: [],
};

export function canAccess(url: string, roles: AppRole[]): boolean {
  if (roles.includes("super_admin")) return true;
  const allowed = ROUTE_PERMISSIONS[url];
  if (allowed === undefined) return true;
  if (allowed.length === 0) return false; // explicitement super_admin only
  // Gestionnaire de Stock : accès à toutes les routes opérationnelles ERP
  // (tout sauf les routes Administration marquées super_admin only ci-dessus).
  if (roles.includes("gestionnaire_stock")) return true;
  return allowed.some((r) => roles.includes(r));
}

/**
 * Restrictions par utilisateur (email) — surcouche RBAC.
 * Permet d'interdire l'accès à certaines routes (préfixes) pour un user
 * précis, indépendamment de ses rôles. Appliqué côté frontend (menus +
 * garde de route). Côté backend, des policies RLS restrictives bloquent
 * également l'accès aux données concernées.
 */
export const USER_RESTRICTIONS: Record<string, string[]> = {
  "yakeben@editionsfabsci.com": ["/incidents", "/alertes-stock", "/transferts"],
};

export function isUserRestricted(email: string | null | undefined, url: string): boolean {
  if (!email) return false;
  const list = USER_RESTRICTIONS[email.toLowerCase()];
  if (!list) return false;
  return list.some((prefix) => url === prefix || url.startsWith(prefix + "/"));
}

export function canAccessAs(
  url: string,
  roles: AppRole[],
  email: string | null | undefined,
): boolean {
  if (isUserRestricted(email, url)) return false;
  return canAccess(url, roles);
}

export function hasPermission(perm: Permission, roles: AppRole[]): boolean {
  if (roles.includes("super_admin")) return true;
  // Gestionnaire de Stock : toutes permissions granulaires sauf Administration.
  const ADMIN_PERMS: Permission[] = [
    "view_utilisateurs",
    "manage_utilisateurs",
    "admin_settings",
    "audit_log",
  ];
  if (roles.includes("gestionnaire_stock") && !ADMIN_PERMS.includes(perm)) return true;
  const allowed = PERMISSIONS[perm] ?? [];
  return allowed.some((r) => roles.includes(r));
}

/**
 * Modules en lecture seule pour certains rôles.
 * Le directeur commercial consulte Clients, Commandes et Livraisons
 * sans pouvoir créer, modifier ou supprimer (matrice FABS-CI V10).
 */
const READ_ONLY_MATRIX: Partial<Record<AppRole, string[]>> = {
  directeur_commercial: ["clients", "commandes", "livraisons", "specimens"],
};

/** Rôles autorisés à créer / modifier / valider / annuler une remise de spécimens. */
export const SPECIMENS_WRITE_ROLES: AppRole[] = [
  "super_admin",
  "directeur_general",
  "gestionnaire_stock",
  "responsable_magasinier",
];

export function canMutateSpecimen(roles: AppRole[]): boolean {
  if (roles.includes("super_admin")) return true;
  return SPECIMENS_WRITE_ROLES.some((r) => roles.includes(r));
}

export function isReadOnly(module: string, roles: AppRole[]): boolean {
  if (roles.includes("super_admin")) return false;
  // Si l'utilisateur a au moins un rôle "écriture" pour ce module, ce n'est
  // pas read-only. Sinon, dès qu'un de ses rôles l'indique read-only, on bloque.
  const writers = roles.filter((r) => !(READ_ONLY_MATRIX[r] ?? []).includes(module));
  if (writers.length > 0) return false;
  return roles.some((r) => (READ_ONLY_MATRIX[r] ?? []).includes(module));
}
