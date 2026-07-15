import { supabase } from "@/integrations/supabase/client";
import {
  generateIncidentPDF,
  generateRapportIncidentsPDF,
  type IncidentPdfData,
  type IncidentLignePdf,
  type RapportIncidentsData,
} from "@/lib/pdf/fabsTemplates";
import {
  getIncident,
  getIncidentLignes,
  listIncidents,
  TYPE_INCIDENT_LABEL,
  STATUT_INCIDENT_LABEL,
} from "@/lib/incidents-api";

/**
 * Charge un incident + ses lignes enrichies (prix produit, dépôt, déclarant)
 * puis génère le PDF officiel FABS-CI. Aucun calcul manuel : toutes les
 * valeurs sont recalculées ici (Σ ligne = quantité × prix produit).
 */
export async function buildIncidentPdfBlob(incidentId: string): Promise<Blob> {
  const [incident, lignes] = await Promise.all([
    getIncident(incidentId),
    getIncidentLignes(incidentId),
  ]);

  // Enrichissement produits (prix unitaire + unité)
  const produitIds = Array.from(new Set(lignes.map((l) => l.produit_id))).filter(Boolean);
  const prixMap = new Map<string, { prix: number; unite: string | null }>();
  if (produitIds.length > 0) {
    const { data } = await supabase
      .from("produits")
      .select("produit_id, prix_vente")
      .in("produit_id", produitIds);
    for (const p of (data ?? []) as Array<{ produit_id: string; prix_vente: number | null }>) {
      prixMap.set(p.produit_id, {
        prix: Number(p.prix_vente ?? 0),
        unite: null,
      });
    }
  }

  // Déclarant : `reporter_nom` sinon `responsable_nom`.
  const declarant: string | null =
    (incident as unknown as { reporter_nom?: string | null }).reporter_nom ??
    incident.responsable_nom ??
    null;

  const dateIncident = incident.date_incident;
  const heureIncident = (() => {
    const d = new Date(incident.date_incident);
    if (isNaN(d.getTime())) return null;
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  })();

  const st = STATUT_INCIDENT_LABEL[incident.statut];
  const typeLabel = TYPE_INCIDENT_LABEL[incident.type_incident] ?? incident.type_incident;

  const lignesPdf: IncidentLignePdf[] = lignes.map((l, i) => {
    const info = prixMap.get(l.produit_id);
    const prix = info?.prix ?? 0;
    return {
      numero: i + 1,
      reference: l.reference_produit ?? "",
      designation: l.designation,
      quantite: l.quantite,
      unite: info?.unite ?? "",
      valeurUnitaire: prix,
      valeurTotale: Math.round(prix * l.quantite),
      observation: "",
    };
  });

  const data: IncidentPdfData = {
    numero: incident.numero ?? incident.reference,
    dateIncident,
    heureIncident,
    depot: incident.depots?.nom ?? null,
    magasin: incident.depots?.code ?? null,
    responsable: incident.responsable_nom ?? null,
    typeIncident: typeLabel,
    statut: st ? { label: st.label, color: st.color } : null,
    gravite: incident.gravite ?? null,
    declarant,
    dateDeclaration: incident.created_at,
    motif: incident.motif ?? null,
    observations: incident.observations ?? null,
    lignes: lignesPdf,
  };

  return generateIncidentPDF(data);
}

export function incidentPdfFilename(numero: string): string {
  const safe = numero.replace(/[^A-Za-z0-9_-]+/g, "_");
  return `Incident_${safe}.pdf`;
}

/**
 * Rapport d'incidents (liste) — même charte, valeurs recalculées à partir des
 * incidents filtrés (nb, quantité, coût estimé DB).
 */
export async function buildRapportIncidentsPdfBlob(filters?: {
  q?: string;
  statut?: string;
  type?: string;
  depot_id?: string;
  periodeLabel?: string;
  filtresLabel?: string;
}): Promise<Blob> {
  const incidents = await listIncidents({
    q: filters?.q,
    statut: filters?.statut,
    type: filters?.type,
    depot_id: filters?.depot_id,
  });
  const lignes = incidents.map((inc) => ({
    numero: inc.numero ?? inc.reference,
    date: inc.date_incident,
    type: TYPE_INCIDENT_LABEL[inc.type_incident] ?? inc.type_incident,
    magasin: inc.depots?.nom ?? null,
    nbProduits: inc.nb_produits,
    quantite: inc.total_quantite,
    valeur: Number((inc as unknown as { cout_estime?: number }).cout_estime ?? 0),
    statut: STATUT_INCIDENT_LABEL[inc.statut]?.label ?? inc.statut,
  }));
  const data: RapportIncidentsData = {
    reference: `RAP-INC-${new Date().toISOString().slice(0, 10)}`,
    periodeLabel: filters?.periodeLabel ?? "Tous les incidents",
    filtresLabel: filters?.filtresLabel ?? null,
    lignes,
  };
  return generateRapportIncidentsPDF(data);
}