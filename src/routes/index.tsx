import { createFileRoute, Navigate } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  component: () => {
    // Redirection automatique vers le tableau de bord
    return <Navigate to="/dashboard" />;
  },
});

/**
 * COMPLÉMENT AU WORKFLOW DES COMMANDES – Exécution des traitements uniquement après validation
 * 
 * Principe fondamental
 * La création d'une commande et la génération d'une proforma ne doivent déclencher aucun traitement métier.
 * La proforma est uniquement un document commercial en attente de validation.
 * 
 * ---
 * Étape 1 : Création de la commande
 * Lorsqu'une commande est enregistrée :
 * - la commande est créée ;
 * - la proforma est générée automatiquement ;
 * - le statut devient En attente de validation.
 * 
 * À cette étape, le système ne doit effectuer aucune des opérations suivantes :
 * - aucune sortie de stock ;
 * - aucune réservation ou mouvement de stock ;
 * - aucune écriture comptable ;
 * - aucune opération financière ;
 * - aucune paiement ;
 * - aucun mouvement de caisse ;
 * - aucun mouvement bancaire ;
 * - aucune mise à jour des statistiques de chiffre d'affaires ;
 * - aucune création de dette ou de créance ;
 * - aucune exécution logistique ;
 * - aucune préparation de livraison ;
 * - aucune génération de bon de livraison ;
 * - aucune génération de facture ;
 * - aucun impact sur les tableaux de bord ou les indicateurs métier.
 * 
 * La proforma est uniquement un document d'attente.
 * 
 * ---
 * Étape 2 : Validation de la commande
 * C'est uniquement au moment de la validation que le système doit exécuter tous les traitements métiers.
 * 
 * Après validation, le système doit automatiquement :
 * - transformer la proforma en facture ;
 * - générer le bon de livraison ;
 * - effectuer les mouvements de stock ;
 * - mettre à jour les quantités disponibles ;
 * - créer les écritures comptables ;
 * - créer les créances du client ;
 * - alimenter les états financiers ;
 * - mettre à jour les tableaux de bord et les statistiques ;
 * - lancer les traitements logistiques ;
 * - enregistrer tous les historiques et journaux d'audit ;
 * - exécuter tous les autres traitements liés à une commande confirmée.
 * 
 * ---
 * Règle métier obligatoire
 * Aucun traitement métier ne doit être exécuté tant que la commande est au statut "En attente de validation".
 * Le changement de statut vers Confirmée constitue le seul déclencheur autorisé pour l'ensemble des traitements de l'ERP.
 * 
 * Cette règle doit être appliquée de manière uniforme dans tous les modules afin de garantir la cohérence des données, la traçabilité des opérations et le respect des bonnes pratiques de gestion.
 */
