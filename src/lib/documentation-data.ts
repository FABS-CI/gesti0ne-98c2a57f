export type DocSection = {
  id: string;
  module: string;
  title: string;
  route?: string;
  content: string;
};

export const DOC_SECTIONS: DocSection[] = [
  {
    id: "connexion",
    module: "Général",
    title: "Connexion & sécurité",
    content:
      "Ouvrir l'URL de l'ERP, saisir email professionnel et mot de passe. Google Sign-In disponible si activé. Session expirée après 1h d'inactivité : se reconnecter. Erreur 'Accès refusé' : votre rôle ne couvre pas la page, contacter le Super Admin. Ne jamais partager son mot de passe. Ne jamais laisser une session ouverte sur un poste non verrouillé.",
  },
  {
    id: "navigation",
    module: "Général",
    title: "Navigation & recherche globale",
    content:
      "Menu latéral = modules autorisés par votre rôle. Recherche globale via Ctrl+K ou Cmd+K (clients, factures, produits, commandes). Notifications : cloche en haut à droite, à traiter avant fin de journée. Fil d'Ariane pour revenir sans perdre les filtres.",
  },
  {
    id: "roles",
    module: "Général",
    title: "Rôles et responsabilités",
    content:
      "Super Admin : utilisateurs, rôles, paramètres, exercices, audit. Direction Générale : lecture globale, KPI, comparatifs. Comptable : factures, paiements, exercices, états de compte. Commercial / Secrétariat : clients, proformas, commandes, livraisons, retours. Gestionnaire de stock : réceptions, transferts, inventaires, ajustements. Livreur : tournées, bons de livraison, preuves. RH : employés, contrats, paie, congés, absences.",
  },
  {
    id: "clients",
    module: "Commercial",
    title: "Créer et gérer un client",
    route: "/clients",
    content:
      "Créer un client : nom, type (particulier/société), téléphone, email, adresse, conditions de paiement, commercial référent. Vérifier les doublons (recherche par nom ou téléphone) avant toute création. Ne jamais modifier le code client d'un compte actif. Fusion des doublons via Super Admin.",
  },
  {
    id: "proformas",
    module: "Commercial",
    title: "Proformas — création et conversion",
    route: "/proformas",
    content:
      "Nouvelle proforma : sélectionner client, ajouter lignes (produit + quantité + prix). Vérifier remises, TVA, total. Envoyer au format PDF. Convertir en commande à l'accord du client via le bouton Convertir.",
  },
  {
    id: "commandes",
    module: "Commercial",
    title: "Commandes — cycle de vie",
    route: "/commandes",
    content:
      "Créer une commande depuis une proforma (bouton Convertir) ou de zéro. Vérifier la disponibilité stock (colonne dispo). Valider pour générer la préparation. Statuts : nouvelle, en préparation, expédiée, livrée, facturée. Ne jamais modifier les quantités d'une commande validée sans passer par un avenant.",
  },
  {
    id: "colisage",
    module: "Commercial",
    title: "Colisage et étiquettes",
    route: "/colisage",
    content:
      "Ouvrir la commande à préparer. Ordre de colisage : constitution des colis (produits + quantités). Imprimer étiquettes colis. Marquer prêt.",
  },
  {
    id: "livraisons",
    module: "Commercial",
    title: "Livraisons et bons de livraison",
    route: "/livraison-suivi",
    content:
      "Créer la livraison depuis la commande. Assigner livreur, véhicule et tournée. Imprimer le bon de livraison. Suivi de tournée en temps réel. Au retour livreur : valider la livraison avec preuve (signature ou photo).",
  },
  {
    id: "retours",
    module: "Commercial",
    title: "Retours clients",
    route: "/retours",
    content:
      "Retour client : SAV ou erreur de livraison. Générer bon de retour et avoir si applicable. Ne jamais supprimer une facture pour compenser un retour.",
  },
  {
    id: "factures",
    module: "Comptabilité",
    title: "Émettre une facture",
    route: "/factures",
    content:
      "Nouvelle facture : sélectionner un client existant (jamais un libellé libre). Rattacher la commande d'origine si applicable, le montant est recalculé. Vérifier date facture, date échéance, exercice comptable actif. Valider fige le numéro FAC-xxxxx. Une facture validée ne se modifie pas : émettre un avoir. Facture sur exercice clôturé : blocage automatique.",
  },
  {
    id: "paiements",
    module: "Comptabilité",
    title: "Enregistrer un paiement",
    route: "/paiements/nouveau",
    content:
      "Sélectionner le client, cocher la ou les factures à imputer. Saisir montant reçu, mode (espèces, virement, chèque, mobile money), référence obligatoire, date. Vérifier le récapitulatif : reste avant, montant imputé, reste après. Valider. Contrôles : montant supérieur à zéro, montant inférieur ou égal au solde restant, référence non vide. Impact : montant_paye augmente, statut recalculé (impayée, partielle, payée).",
  },
  {
    id: "annulation-paiement",
    module: "Comptabilité",
    title: "Annuler un paiement",
    content:
      "Réservé Super Admin, DG, Comptable. Ouvrir le paiement, cliquer Annuler, saisir la raison obligatoire et des notes, confirmer. Le paiement passe au statut annulé, montant_paye est diminué, statut de la facture recalculé. Ligne écrite au journal d'audit /admin/audit-paiements. Ne jamais compenser en créant un paiement négatif.",
  },
  {
    id: "etat-compte",
    module: "Comptabilité",
    title: "États de compte clients",
    route: "/etat-compte-clients",
    content:
      "Total dû = somme des soldes des factures non payées, tous exercices confondus. Clients débiteurs = nombre de clients avec un solde strictement supérieur à zéro. Total clients = nombre total de clients enregistrés. Export PDF par client avec détail facture par facture et paiements imputés. Si Total dû = 0, toutes les factures sont payées.",
  },
  {
    id: "exercices",
    module: "Comptabilité",
    title: "Exercices et clôture",
    route: "/exercices",
    content:
      "Un exercice est une période comptable (souvent un an). Seul l'exercice ouvert accepte de nouvelles écritures. Clôturer bloque toute modification : préparer d'abord le lettrage, les rapprochements, les provisions. Report à nouveau : les soldes clients et fournisseurs basculent sur l'exercice suivant. Comparatif multi-exercices : /exercices/comparatif.",
  },
  {
    id: "fournisseurs",
    module: "Stock",
    title: "Gérer les fournisseurs",
    route: "/fournisseurs",
    content:
      "Les fiches fournisseurs centralisent raison sociale, représentant, téléphone et email. Utile pour les approvisionnements et le suivi des dettes. Un fournisseur inactif ne peut plus être sélectionné pour un nouvel achat.",
  },
  {
    id: "produits",
    module: "Stock",
    title: "Produits et fiches article",
    route: "/produits",
    content:
      "Consulter la fiche produit : référence, catégorie, unité, seuil d'alerte, stocks par dépôt. Ne jamais dupliquer un article, vérifier avant création.",
  },
  {
    id: "reception",
    module: "Stock",
    title: "Réception d'achat",
    route: "/achats",
    content:
      "Prérequis : bon d'achat validé. Ouvrir l'achat, cliquer Réceptionner. Pour chaque ligne : saisir la quantité réellement reçue (peut être inférieure à la quantité commandée). Vérifier état, lot, DLC. Valider génère un bon de livraison fournisseur et un mouvement de stock entrée. Ne jamais réceptionner sans vérification physique.",
  },
  {
    id: "transferts",
    module: "Stock",
    title: "Transferts inter-dépôts",
    route: "/transferts",
    content:
      "Créer un transfert : dépôt source, dépôt destination, lignes (produits + quantités). Expédier (sortie du dépôt source). Réceptionner (entrée au dépôt destination) obligatoire pour clôturer. Un transfert expédié non réceptionné crée un stock en transit fantôme : contrôle hebdomadaire obligatoire.",
  },
  {
    id: "inventaires",
    module: "Stock",
    title: "Inventaires physiques",
    route: "/inventaires",
    content:
      "Créer un inventaire (dépôt, date, partiel ou total). Imprimer la feuille de comptage. Compter physiquement, saisir les quantités. Comparer théorique vs compté, les écarts s'affichent. Valider génère un ajustement automatique. Double-comptage obligatoire des écarts au-delà du seuil.",
  },
  {
    id: "ajustements",
    module: "Stock",
    title: "Ajustements manuels",
    content:
      "Réservés aux cas exceptionnels (casse constatée, vol). Motif obligatoire, validation Super Admin.",
  },
  {
    id: "rapports-stock",
    module: "Stock",
    title: "Rapports de stock",
    route: "/rapports",
    content:
      "Stock actuel par dépôt. Rotation : produits sans mouvement au-delà de 90 jours. Ruptures et seuils d'alerte : liste rouge. KPI : valeur totale, nombre de ruptures, écart d'inventaire en pourcentage.",
  },
  {
    id: "pdf-documents",
    module: "Documents",
    title: "Documents PDF (facture, BL, proforma)",
    content:
      "Génération automatique : facture, proforma, bon de livraison, bon de commande, avoir, état de compte. En-tête avec logo et coordonnées société. Pied avec mentions légales et numéro de page. Chaque PDF est signé (horodatage et utilisateur émetteur). Réimprimer possible à tout moment depuis la fiche de la pièce.",
  },
  {
    id: "erreurs-courantes",
    module: "Dépannage",
    title: "Erreurs fréquentes",
    content:
      "Accès refusé : rôle insuffisant, demander au Super Admin. Le montant dépasse le solde restant : sur-paiement, réduire ou répartir. Référence obligatoire : saisir n° chèque, transaction ou reçu. Écriture sur exercice clôturé : utiliser un exercice ouvert. Stock négatif bloqué : effectuer une entrée ou un transfert. Transfert en transit : réceptionner côté destination. Doublon client : fusionner via Super Admin.",
  },
  {
    id: "checklist",
    module: "Bonnes pratiques",
    title: "Checklist quotidienne",
    content:
      "Début de journée : vérifier l'exercice actif, traiter les notifications de la veille, consulter les KPI dashboard (CA jour, encaissements, ruptures stock). Fin de journée : toutes les commandes livrées validées avec preuve, toutes les livraisons facturées ou planifiées sous 48h, rapprochement de caisse, transferts non réceptionnés relancés, aucun paiement en attente de référence.",
  },
  {
    id: "regles-or",
    module: "Bonnes pratiques",
    title: "Règles d'or de l'ERP",
    content:
      "Zéro suppression : utiliser avoir, retour ou mouvement inverse. Zéro libellé libre : toujours sélectionner l'entité existante. Zéro modification après validation d'une pièce. Traçabilité totale : chaque action laisse une trace utilisateur et horodatage.",
  },
];