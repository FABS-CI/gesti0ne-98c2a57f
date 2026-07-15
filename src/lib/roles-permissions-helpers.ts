import { ACTIONS, type ActionCode } from "@/lib/rbac-catalog";

/**
 * Actions qui, si accordées, exigent implicitement la permission `voir`
 * sur le même sous-module. La règle de cohérence est appliquée côté client
 * avant chaque toggle pour éviter les « droits orphelins ».
 */
export const ACTIONS_REQUIRING_VOIR: ActionCode[] = [
  "creer",
  "modifier",
  "supprimer",
  "valider",
  "annuler",
  "imprimer",
  "telecharger",
  "exporter_pdf",
  "exporter_excel",
  "importer",
  "dupliquer",
  "archiver",
  "changer_statut",
  "voir_prix",
  "voir_couts",
  "voir_marges",
  "voir_ca",
  "voir_stats",
  "voir_historique",
  "acceder_parametres",
];

/**
 * Depuis un code permission `sous_module.action`, renvoie :
 *  - `voirCode` : le code `voir` du même sous-module (si l'action l'exige) ;
 *  - `derivedCodes` : la liste des codes dérivés d'un même sous-module
 *    (utilisée si on retire `voir` — on doit cascade-retirer les dérivés).
 */
export function coherenceFor(code: string, allCodes: Set<string>) {
  const [sm, action] = code.split(".") as [string, string];
  const voirCode = `${sm}.voir`;
  const requiresVoir =
    ACTIONS_REQUIRING_VOIR.includes(action as ActionCode) && allCodes.has(voirCode);
  const derivedCodes = ACTIONS_REQUIRING_VOIR.map((a) => `${sm}.${a}`).filter((c) =>
    allCodes.has(c),
  );
  return { voirCode, requiresVoir, derivedCodes, isVoir: action === "voir" };
}

export type Preset = {
  key: string;
  label: string;
  description: string;
  actions: ActionCode[] | "all" | "none";
};

export const PRESETS: Preset[] = [
  {
    key: "read",
    label: "Lecture seule",
    description: "Consulter, historique, stats",
    actions: ["voir", "voir_historique", "voir_stats"],
  },
  {
    key: "input",
    label: "Saisie",
    description: "Consulter, créer, modifier, dupliquer, importer",
    actions: ["voir", "creer", "modifier", "dupliquer", "importer"],
  },
  {
    key: "validation",
    label: "Validation",
    description: "Saisie + valider, annuler, changer statut",
    actions: [
      "voir",
      "creer",
      "modifier",
      "valider",
      "annuler",
      "changer_statut",
    ],
  },
  {
    key: "manager",
    label: "Responsable",
    description: "Validation + suppression, archivage, exports, prix/CA",
    actions: [
      "voir",
      "creer",
      "modifier",
      "supprimer",
      "valider",
      "annuler",
      "changer_statut",
      "archiver",
      "imprimer",
      "telecharger",
      "exporter_pdf",
      "exporter_excel",
      "voir_prix",
      "voir_ca",
      "voir_stats",
      "voir_historique",
    ],
  },
  {
    key: "full",
    label: "Accès complet",
    description: "Toutes les actions (y compris paramètres)",
    actions: "all",
  },
  {
    key: "none",
    label: "Aucun",
    description: "Retire toutes les permissions",
    actions: "none",
  },
];

export function presetCodes(sousModuleCode: string, preset: Preset): string[] {
  if (preset.actions === "none") return [];
  if (preset.actions === "all") return ACTIONS.map((a) => `${sousModuleCode}.${a.code}`);
  return preset.actions.map((a) => `${sousModuleCode}.${a}`);
}
