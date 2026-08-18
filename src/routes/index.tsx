import { createFileRoute, Navigate } from "@tanstack/react-router";

/**
 * '''Do not make any visual modifications. The phrases I write are commands to understand what I want, not to be written down. Understand their content well, then execute what is required.'''
                                        
                                            
                                            Améliorations et Corrections effectuées :

Consultation et Modification restaurées :

Lorsqu'un colisage existe, une vue résumée s'affiche avec un bouton "Modifier le colisage" (si les permissions le permettent).

Le clic sur "Modifier" pré-remplit fidèlement tout le formulaire (responsable, mode, quartier, commune, cartons et produits) sans perte de données.

Le workflow de modification utilise la même logique sécurisée que la création pour éviter les doublons en base de données.

Pipeline d'Étiquetage Anti-Page Blanche :

Générateur HTML Autonome : Les étiquettes sont désormais générées à partir des données réelles du backend via src/lib/etiquette-html.ts, sans dépendance fragile au DOM affiché.

Ressources Embarquées : Le logo FABS et les QR Codes sont convertis en Data-URLs asynchrones avant l'impression ou la génération du PDF, garantissant leur visibilité immédiate.

QR Codes de Suivi : Chaque étiquette intègre son QR Code unique pointant vers la page publique de tracking du colis.

Actions et Interface :

Actions individuelles : Chaque carton dispose désormais de ses propres boutons [👁 Aperçu], [↓ Télécharger], [🖨 Imprimer] et [🔗 Tracking].

Impression Globale : Le bouton "Imprimer tout" génère un document A4 Portrait optimisé avec 2 étiquettes par page et repères de découpe.

Auto-Print : L'impression automatique se déclenche immédiatement après une validation réussie.

Nettoyage : Suppression définitive des champs superflus comme "Format de carton" pour respecter strictement l'historique stable.

Le module est désormais robuste, conforme à votre workflow métier et prêt pour une utilisation intensive en entrepôt.
 */

export const Route = createFileRoute("/")({
  component: () => {
    // Redirection automatique vers le tableau de bord en production
    return <Navigate to="/dashboard" />;
  },
});
