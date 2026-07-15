/**
 * Module FNE (Facture Normalisée Électronique — DGI Côte d'Ivoire)
 * Point d'entrée public — ré-exporte les modules `src/lib/fne/*`.
 * Split en modules pour lisibilité : types / settings / submit / reads.
 */
export * from "./fne/types";
export * from "./fne/settings";
export * from "./fne/submit";
export * from "./fne/reads";
