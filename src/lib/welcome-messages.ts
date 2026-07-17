/**
 * Bibliothèque de messages de bienvenue intelligents.
 *
 * - Adaptés au rôle (direction, commercial, comptable, stock, logistique, RH…)
 * - Contextuels (lundi, vendredi, début / fin de mois, début d'année)
 * - Rotation anti-répétition (mémoire locale des dernières citations vues)
 */

import type { AppRole } from "@/hooks/use-user-roles";

export type WelcomeRoleKey =
  | "direction"
  | "commercial"
  | "comptable"
  | "stock"
  | "logistique"
  | "secretariat"
  | "rh"
  | "admin"
  | "employe";

/** Mappe un rôle applicatif vers une famille de messages. */
export function roleKeyFromAppRoles(roles: readonly AppRole[]): WelcomeRoleKey {
  const has = (r: AppRole) => roles.includes(r);
  if (has("super_admin")) return "admin";
  if (has("directeur_general")) return "direction";
  if (has("directeur_commercial")) return "commercial";
  if (has("comptable")) return "comptable";
  if (has("gestionnaire_stock") || has("responsable_magasinier")) return "stock";
  if (has("service_logistique")) return "logistique";
  if (has("secretariat") || has("assistante")) return "secretariat";
  return "employe";
}

export const ROLE_LABEL: Record<WelcomeRoleKey, string> = {
  direction: "Direction générale",
  commercial: "Équipe commerciale",
  comptable: "Comptabilité",
  stock: "Gestion des stocks",
  logistique: "Service logistique",
  secretariat: "Secrétariat",
  rh: "Ressources humaines",
  admin: "Administration",
  employe: "Collaborateur",
};

/* ─────────────────────── Bibliothèques de messages ─────────────────────── */

const DIRECTION = [
  "Diriger, c'est éclairer la route. Vos décisions d'aujourd'hui bâtissent la performance de demain.",
  "Une vision claire, des équipes engagées : votre leadership est le socle de la réussite collective.",
  "Excellence, rigueur et exemplarité — trois piliers que vous incarnez au quotidien.",
  "Chaque indicateur consulté est une opportunité de piloter, d'ajuster, d'améliorer.",
  "La stratégie prend vie dans l'exécution. Merci pour votre exigence.",
  "Prendre du recul pour mieux avancer : bonne journée de pilotage.",
  "Vos arbitrages orientent l'entreprise. Que la journée soit lucide et efficace.",
  "Un dirigeant inspiré inspire toute une organisation. Belle journée à vous.",
  "Les grandes réussites naissent d'une gouvernance rigoureuse. Merci pour votre engagement.",
  "Piloter avec des données fiables, décider avec sérénité — le tableau de bord vous attend.",
  "Chaque revue de performance est une pierre ajoutée à l'édifice.",
  "L'excellence opérationnelle commence par des indicateurs suivis avec méthode.",
  "Cap sur les objectifs : gardez le rythme, la direction et l'ambition.",
  "Vos équipes comptent sur votre clarté. Belle journée de décision.",
  "Un bon dirigeant écoute, mesure, tranche. Bonne journée de pilotage stratégique.",
];

const COMMERCIAL = [
  "Chaque client satisfait est une relation qui se construit dans la durée. Votre écoute fait la différence.",
  "Un devis soigné aujourd'hui, c'est une commande signée demain. Bonne journée de conquête.",
  "La confiance se gagne minute par minute. Votre professionnalisme est votre meilleure signature.",
  "Un client bien servi devient un ambassadeur. Merci pour votre exigence commerciale.",
  "Vendre, c'est comprendre. Prenez le temps d'écouter — la valeur suivra.",
  "Chaque appel, chaque email est une opportunité de créer de la valeur.",
  "Votre réactivité fait toute la différence sur un marché exigeant.",
  "La régularité prime sur l'exploit : nourrissez votre pipeline avec méthode.",
  "Un bon commercial ne vend pas un produit, il résout un problème.",
  "Les objectifs se construisent client par client. Belle journée de conversion.",
  "Relancer avec élégance, conclure avec précision : bonne journée sur le terrain.",
  "Un CRM tenu à jour vaut mille promesses. Merci pour votre rigueur.",
  "Le professionnalisme se voit dans le détail : ponctualité, suivi, respect des engagements.",
  "Vendre, c'est servir. Belle journée au service de vos clients.",
  "Chaque « oui » commence par une écoute sincère. Bonne journée.",
];

const COMPTABLE = [
  "Votre rigueur dans les écritures est un pilier de la fiabilité de l'entreprise.",
  "La comptabilité est le langage de l'entreprise. Merci de le parler avec précision.",
  "Chaque pièce justifiée, chaque écriture équilibrée : c'est la confiance qui se construit.",
  "L'exactitude d'aujourd'hui évite les corrections de demain. Belle journée de rigueur.",
  "Un lettrage propre, une balance claire — merci pour votre exigence.",
  "Vos états financiers guident les décisions de toute l'entreprise.",
  "La comptabilité bien tenue, c'est la sérénité pour la direction. Bravo.",
  "Débit à gauche, crédit à droite — et la vérité au milieu. Excellente journée.",
  "Chaque rapprochement bancaire est un gage de transparence.",
  "Le respect des délais fiscaux commence par la discipline quotidienne. Merci.",
  "Votre travail invisible fait la solidité visible de l'entreprise.",
  "La qualité comptable n'est jamais un hasard, elle est une méthode. Bonne journée.",
  "Une écriture juste aujourd'hui, un bilan serein demain.",
  "Confidentialité, intégrité, précision : les trois vertus du bon comptable.",
  "Merci pour la fiabilité de vos chiffres — ils font autorité.",
];

const STOCK = [
  "Un stock bien tenu, c'est une entreprise qui livre à temps. Merci pour votre vigilance.",
  "Chaque référence comptée, chaque emplacement respecté : la fiabilité commence ici.",
  "L'inventaire d'aujourd'hui évite les ruptures de demain.",
  "Un magasin ordonné est un magasin performant. Belle journée.",
  "Votre œil expert protège l'entreprise des écarts et des pertes.",
  "Un mouvement enregistré, c'est une traçabilité assurée. Merci pour votre rigueur.",
  "Ranger, contrôler, sécuriser : trois gestes qui font la différence.",
  "Le respect des procédures est la meilleure garantie de fiabilité.",
  "Un stock juste est un stock qui inspire confiance à toute l'entreprise.",
  "Chaque alerte traitée à temps évite un client mécontent.",
  "Vous êtes la mémoire physique de l'entreprise. Merci pour votre engagement.",
  "Une entrée bien saisie, une sortie bien tracée : la comptabilité vous remerciera.",
  "La sécurité du dépôt est une responsabilité collective — vous en êtes le premier acteur.",
  "Bien compter, c'est déjà bien gérer. Belle journée.",
  "Votre rigueur au quotidien évite bien des tensions. Merci.",
];

const LOGISTIQUE = [
  "Livrer à temps, c'est tenir la promesse commerciale. Bonne route.",
  "Chaque colis préparé avec soin est un client rassuré.",
  "L'organisation d'une tournée fait la différence entre effort et efficacité.",
  "Un bon de livraison bien renseigné vaut mille explications.",
  "Votre professionnalisme sur le terrain porte l'image de l'entreprise.",
  "Un client accueilli avec sourire garde le sourire pour la prochaine commande.",
  "La ponctualité est votre première signature. Belle journée.",
  "Bien préparer, bien charger, bien livrer : la chaîne ne casse jamais si chaque maillon est solide.",
  "La sécurité en tournée n'est pas négociable. Prenez soin de vous.",
  "Un retour anticipé est un problème évité. Merci de communiquer.",
  "Vos comptes-rendus de tournée nourrissent l'amélioration continue.",
  "Chaque livraison réussie renforce la relation client.",
  "L'excellence logistique se joue dans les détails : étiquetage, emballage, timing.",
  "Livrer, c'est aussi représenter l'entreprise. Merci de le faire avec fierté.",
  "Bonne tournée — que la route vous soit favorable.",
];

const SECRETARIAT = [
  "Vous êtes la première voix, la première image de l'entreprise. Merci pour votre bienveillance.",
  "Un accueil soigné pose le ton de toute la relation. Belle journée.",
  "Organiser, classer, anticiper : votre calme est un atout collectif.",
  "Chaque document bien classé fait gagner du temps à toute l'équipe.",
  "Votre discrétion et votre sens du service sont précieux.",
  "Un agenda bien tenu, ce sont des décisions prises à temps.",
  "Merci de faire tourner la machine avec autant d'élégance.",
  "La qualité d'accueil est un investissement invisible mais décisif.",
  "Répondre avec sourire, écrire avec précision : deux talents précieux.",
  "Un secrétariat organisé, c'est une entreprise sereine.",
  "Vous êtes le lien entre les équipes, les clients et la direction. Bravo.",
  "La confidentialité fait partie de votre professionnalisme quotidien. Merci.",
  "Rigueur et amabilité — le duo gagnant. Belle journée.",
  "Chaque courrier soigné valorise l'image de l'entreprise.",
  "Merci pour votre disponibilité et votre esprit d'équipe.",
];

const RH = [
  "Les ressources humaines sont d'abord humaines : merci pour votre écoute.",
  "Un dossier bien tenu, c'est un collaborateur respecté.",
  "Vos actions de proximité renforcent l'engagement de tous.",
  "Confidentialité et équité : deux principes que vous incarnez chaque jour.",
  "Recruter, former, accompagner — vous construisez l'avenir de l'entreprise.",
  "Un contrat clair, une paie juste : la confiance commence là.",
  "La qualité du dialogue social passe par votre disponibilité. Merci.",
  "Vos évaluations éclairent les parcours et révèlent les talents.",
  "Bien intégrer, c'est déjà bien fidéliser. Belle journée.",
  "La gestion des congés et absences demande rigueur et empathie — vous cumulez les deux.",
  "Vous êtes le gardien du climat social. Merci pour votre engagement.",
  "Un tableau de bord RH à jour, c'est une décision managériale éclairée.",
  "Merci pour votre rôle d'écoute et de médiation au quotidien.",
  "Le respect des procédures RH protège l'entreprise et ses collaborateurs.",
  "Votre discrétion fait la solidité du service. Bravo.",
];

const ADMIN = [
  "Vous êtes le gardien du système. Merci pour votre vigilance quotidienne.",
  "La sécurité des données est une responsabilité de chaque instant.",
  "Un rôle bien attribué, un accès bien contrôlé : la gouvernance commence là.",
  "Auditer, tracer, corriger : la fiabilité du système en dépend.",
  "Vos décisions techniques ont un impact métier direct. Bravo pour votre lucidité.",
  "Un ERP maîtrisé, c'est une entreprise agile. Merci.",
  "Sauvegarde, supervision, sécurité — trois mots, une mission essentielle.",
  "Les utilisateurs comptent sur votre disponibilité. Belle journée de pilotage.",
  "Chaque configuration bien faite évite des heures de support demain.",
  "La confidentialité, l'intégrité, la disponibilité — le triptyque que vous protégez.",
  "Merci pour votre capacité à voir loin et à agir vite.",
  "L'excellence opérationnelle passe par votre méthode. Bravo.",
  "Un système bien administré est un système qui inspire confiance.",
  "Vos audits protègent l'entreprise. Belle journée de contrôle.",
  "Merci pour la clarté que vous apportez à la gouvernance des accès.",
];

const EMPLOYE = [
  "Chaque tâche accomplie avec soin contribue à la réussite collective.",
  "La qualité du travail se voit dans les détails. Merci pour votre engagement.",
  "Un professionnel se reconnaît à sa constance. Belle journée.",
  "Votre implication fait la force de l'équipe.",
  "Faire bien ce que l'on fait, c'est déjà exceller. Bonne journée.",
  "Chaque jour est une occasion d'apprendre et de progresser.",
  "L'excellence est une habitude — construisons-la ensemble.",
  "Merci pour votre sérieux et votre esprit d'équipe.",
  "Un travail bien fait n'a jamais besoin d'être refait. Belle journée.",
  "Votre rigueur est un cadeau pour toute l'entreprise.",
  "La ponctualité, la précision, la politesse : trois marques de professionnalisme.",
  "Chaque effort compte. Merci d'être là aujourd'hui.",
  "Ensemble, nous construisons quelque chose qui dépasse chacun de nous.",
  "Un collaborateur engagé fait une entreprise vivante. Bravo.",
  "Bonne journée — que vos efforts portent leurs fruits.",
];

const POOLS: Record<WelcomeRoleKey, readonly string[]> = {
  direction: DIRECTION,
  commercial: COMMERCIAL,
  comptable: COMPTABLE,
  stock: STOCK,
  logistique: LOGISTIQUE,
  secretariat: SECRETARIAT,
  rh: RH,
  admin: ADMIN,
  employe: EMPLOYE,
};

/* ─────────────────────── Messages contextuels ─────────────────────── */

const CONTEXT_MONDAY = [
  "Nous sommes lundi — une nouvelle semaine commence. Fixez le cap, l'énergie suivra.",
  "Lundi : le meilleur jour pour poser des intentions claires. Belle semaine à vous.",
  "Nouvelle semaine, nouvelles opportunités. Bonne reprise.",
];
const CONTEXT_FRIDAY = [
  "Nous sommes vendredi — belle fin de semaine et merci pour le travail accompli.",
  "Vendredi, jour de clôture et de préparation. Terminez fort, reposez-vous bien.",
];
const CONTEXT_MONTH_START = [
  "Un nouveau mois s'ouvre — l'occasion parfaite pour poser de nouveaux objectifs.",
  "Début de mois : préparons ensemble une période exemplaire.",
];
const CONTEXT_MONTH_END = [
  "Fin de mois — moment clé pour clôturer, contrôler, célébrer les résultats.",
  "Dernière ligne droite du mois : rigueur et concentration jusqu'au bout.",
];
const CONTEXT_YEAR_START = [
  "Bonne année ! Que celle-ci soit à la hauteur de vos ambitions professionnelles.",
  "Nouvelle année, nouveau souffle. Belle réussite à toute l'équipe.",
];

/* ─────────────────────── Sélection & rotation ─────────────────────── */

const STORAGE_KEY = "welcome-msg-history-v1";
const HISTORY_LIMIT = 8; // évite les répétitions sur ~8 connexions

type History = Record<string, number[]>;

function readHistory(): History {
  if (typeof window === "undefined") return {};
  try {
    return JSON.parse(window.localStorage.getItem(STORAGE_KEY) ?? "{}") as History;
  } catch {
    return {};
  }
}

function writeHistory(h: History) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(h));
  } catch {
    /* quota — ignore */
  }
}

function pickIndex(pool: readonly string[], recent: readonly number[]): number {
  const available: number[] = [];
  for (let i = 0; i < pool.length; i++) if (!recent.includes(i)) available.push(i);
  const source = available.length > 0 ? available : pool.map((_, i) => i);
  return source[Math.floor(Math.random() * source.length)];
}

export interface WelcomeContext {
  now?: Date;
  storageKey?: string; // permet de tester
}

export interface WelcomePick {
  role: WelcomeRoleKey;
  roleLabel: string;
  message: string;
  contextTag: string | null; // "lundi", "fin-de-mois", …
}

function pickContextual(now: Date): { tag: string; text: string } | null {
  const day = now.getDay(); // 0 = dim, 1 = lun … 6 = sam
  const date = now.getDate();
  const month = now.getMonth();
  const lastDay = new Date(now.getFullYear(), month + 1, 0).getDate();

  // Priorité : nouvel an > fin de mois > début de mois > lundi > vendredi
  if (month === 0 && date <= 5) {
    return { tag: "annee", text: CONTEXT_YEAR_START[Math.floor(Math.random() * CONTEXT_YEAR_START.length)] };
  }
  if (date >= lastDay - 1) {
    return { tag: "fin-de-mois", text: CONTEXT_MONTH_END[Math.floor(Math.random() * CONTEXT_MONTH_END.length)] };
  }
  if (date <= 2) {
    return { tag: "debut-de-mois", text: CONTEXT_MONTH_START[Math.floor(Math.random() * CONTEXT_MONTH_START.length)] };
  }
  if (day === 1) {
    return { tag: "lundi", text: CONTEXT_MONDAY[Math.floor(Math.random() * CONTEXT_MONDAY.length)] };
  }
  if (day === 5) {
    return { tag: "vendredi", text: CONTEXT_FRIDAY[Math.floor(Math.random() * CONTEXT_FRIDAY.length)] };
  }
  return null;
}

export function pickWelcomeMessage(role: WelcomeRoleKey, ctx: WelcomeContext = {}): WelcomePick {
  const now = ctx.now ?? new Date();
  const pool = POOLS[role] ?? POOLS.employe;

  const history = readHistory();
  const recent = history[role] ?? [];
  const idx = pickIndex(pool, recent);
  const base = pool[idx];

  const newRecent = [idx, ...recent].slice(0, HISTORY_LIMIT);
  history[role] = newRecent;
  writeHistory(history);

  const contextual = pickContextual(now);
  const message = contextual ? `${contextual.text} ${base}` : base;

  return {
    role,
    roleLabel: ROLE_LABEL[role],
    message,
    contextTag: contextual?.tag ?? null,
  };
}
