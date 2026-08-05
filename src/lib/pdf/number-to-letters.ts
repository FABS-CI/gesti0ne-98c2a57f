/**
 * Conversion de nombres en lettres (FCFA) pour les documents commerciaux.
 * Basé sur les règles de numération française (système de 1990).
 */

const UNITES = ["", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf"];
const DIX_A_DIX_NEUF = ["dix", "onze", "douze", "treize", "quatorze", "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf"];
const DIZAINES = ["", "dix", "vingt", "trente", "quarante", "cinquante", "soixante", "soixante-dix", "quatre-vingts", "quatre-vingt-dix"];

function convertirGroupe(n: number): string {
  if (n === 0) return "";
  let result = "";

  // Centaines
  const c = Math.floor(n / 100);
  if (c > 0) {
    if (c === 1) {
      result += "cent ";
    } else {
      result += UNITES[c] + " cent" + (n % 100 === 0 ? "s " : " ");
    }
  }

  // Dizaines et unités
  const du = n % 100;
  if (du === 0) return result.trim();

  if (du < 10) {
    result += UNITES[du];
  } else if (du < 20) {
    result += DIX_A_DIX_NEUF[du - 10];
  } else {
    const d = Math.floor(du / 10);
    const u = du % 10;

    if (d === 7) {
      result += "soixante-" + (u === 1 ? "et-onze" : DIX_A_DIX_NEUF[u]);
    } else if (d === 9) {
      result += "quatre-vingt-" + DIX_A_DIX_NEUF[u];
    } else {
      result += DIZAINES[d];
      if (u > 0) {
        result += (u === 1 && d !== 8 ? "-et-" : "-") + UNITES[u];
      }
    }
  }

  return result.trim();
}

export function numberToLetters(n: number): string {
  if (n === 0) return "zéro francs CFA";
  if (n < 0) return "moins " + numberToLetters(Math.abs(n));

  let result = "";
  const milliards = Math.floor(n / 1_000_000_000);
  const millions = Math.floor((n % 1_000_000_000) / 1_000_000);
  const milliers = Math.floor((n % 1_000_000) / 1_000);
  const reste = n % 1_000;

  if (milliards > 0) {
    result += convertirGroupe(milliards) + " milliard" + (milliards > 1 ? "s " : " ");
  }
  if (millions > 0) {
    result += convertirGroupe(millions) + " million" + (millions > 1 ? "s " : " ");
  }
  if (milliers > 0) {
    if (milliers === 1) {
      result += "mille ";
    } else {
      result += convertirGroupe(milliers) + " mille ";
    }
  }
  if (reste > 0) {
    result += convertirGroupe(reste);
  }

  // Nettoyage des tirets et espaces
  const final = result.trim().replace(/--/g, "-").replace(/ -/g, "-").replace(/- /g, "-");
  return (final.charAt(0).toUpperCase() + final.slice(1) + " francs CFA").trim();
}
