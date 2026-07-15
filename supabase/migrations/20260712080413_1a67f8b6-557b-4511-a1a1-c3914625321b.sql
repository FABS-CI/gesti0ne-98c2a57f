-- Correction du trigger de propagation du statut tournée.
-- Business rule (nouveau workflow) : la clôture d'une tournée (statut='terminee')
-- = validation administrative qui déclenche le suivi des livraisons.
-- Ce n'est PAS une livraison effective : les colis passent en transit,
-- pas en 'livré'. La livraison effective est gérée dans le module Suivi
-- (livsuivi_commandes) et remonte les colis vers 'livre' via ses propres RPC.
CREATE OR REPLACE FUNCTION public.propagate_tournee_statut()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    IF NEW.statut IN ('en_cours','terminee','cloturee') THEN
      -- Départ du dépôt / tournée clôturée : colis en transit.
      UPDATE public.colis
         SET statut_logistique = 'en_transit',
             statut = CASE WHEN statut IN ('en_preparation','prete') THEN 'expedie' ELSE statut END,
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut_logistique NOT IN ('livre','retour');
      UPDATE public.livraisons_commande
         SET statut = 'en_livraison'::statut_livraison_cmd,
             heure_depart = COALESCE(heure_depart, now()),
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut NOT IN ('livree'::statut_livraison_cmd, 'annulee'::statut_livraison_cmd);
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;