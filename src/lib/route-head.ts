/**
 * Helper pour les routes authentifiées (ERP interne).
 *
 * - Donne un titre d'onglet distinct par écran (bookmarks, historique).
 * - Ajoute `robots: noindex, nofollow` : ces pages ne doivent jamais
 *   apparaître dans un moteur de recherche public.
 *
 * Le titre root reste le fallback si `title` n'est pas fourni.
 */
export function authRouteHead(title: string) {
  const full = `${title} — FABS-CI`;
  return {
    meta: [
      { title: full },
      { name: "robots", content: "noindex, nofollow" },
      { property: "og:title", content: full },
    ],
  };
}