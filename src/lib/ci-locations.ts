// Villes de Côte d'Ivoire et communes du District d'Abidjan.
// Liste non exhaustive mais couvrant la majorité des destinations.

export const VILLES_CI: string[] = [
  "Abengourou",
  "Abidjan",
  "Aboisso",
  "Adiaké",
  "Adzopé",
  "Agboville",
  "Agnibilékrou",
  "Akoupé",
  "Anyama",
  "Arrah",
  "Bangolo",
  "Bassam",
  "Béoumi",
  "Biankouma",
  "Bingerville",
  "Bloléquin",
  "Bocanda",
  "Bondoukou",
  "Bonoua",
  "Bouaflé",
  "Bouaké",
  "Bouna",
  "Boundiali",
  "Buyo",
  "Dabakala",
  "Dabou",
  "Daloa",
  "Danané",
  "Daoukro",
  "Dimbokro",
  "Divo",
  "Duékoué",
  "Ferkessédougou",
  "Gagnoa",
  "Grand-Bassam",
  "Grand-Lahou",
  "Guiglo",
  "Issia",
  "Katiola",
  "Kong",
  "Korhogo",
  "Lakota",
  "Man",
  "Mankono",
  "Minignan",
  "Odienné",
  "Ouangolodougou",
  "Oumé",
  "Sakassou",
  "San-Pédro",
  "Sassandra",
  "Séguéla",
  "Sinfra",
  "Soubré",
  "Tabou",
  "Tanda",
  "Tengrela",
  "Tiassalé",
  "Tiébissou",
  "Touba",
  "Toulepleu",
  "Toumodi",
  "Vavoua",
  "Yamoussoukro",
  "Zuénoula",
];

// Communes du District Autonome d'Abidjan + communes environnantes.
export const COMMUNES_ABIDJAN: string[] = [
  "Abobo",
  "Adjamé",
  "Anyama",
  "Attécoubé",
  "Bingerville",
  "Brofodoumé",
  "Cocody",
  "Koumassi",
  "Marcory",
  "Plateau",
  "Port-Bouët",
  "Songon",
  "Treichville",
  "Yopougon",
];

/**
 * Normalise une chaîne pour comparaison fiable :
 * - supprime les accents / diacritiques,
 * - passe en minuscules,
 * - remplace tirets / soulignés / apostrophes par des espaces,
 * - fusionne les espaces multiples,
 * - retire les espaces en début / fin.
 *
 * Ex : "  Grand-Bassam  " → "grand bassam", "Yopougon" == "yopougon ".
 */
export function normalize(s: string): string {
  return (s ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/['’]/g, " ")
    .replace(/[-_/]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Filtre une liste selon un terme (insensible aux accents et à la casse). */
export function filterByTerm(list: string[], term: string): string[] {
  const t = normalize(term);
  if (!t) return list;
  return list.filter((x) => normalize(x).includes(t));
}
