
CREATE OR REPLACE FUNCTION public.propagate_tournee_statut()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    IF NEW.statut = 'en_cours' THEN
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
    ELSIF NEW.statut IN ('cloturee','terminee') THEN
      UPDATE public.colis
         SET statut_logistique = 'livre',
             statut = 'livre',
             date_livraison_reelle = COALESCE(date_livraison_reelle, now()),
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut_logistique NOT IN ('livre','retour');
      UPDATE public.livraisons_commande
         SET statut = 'livree'::statut_livraison_cmd,
             date_livraison = COALESCE(date_livraison, now()),
             progression_pct = 100,
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut NOT IN ('livree'::statut_livraison_cmd, 'annulee'::statut_livraison_cmd);
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- Rattrapage des colis bloqués dans des tournées déjà terminées
UPDATE public.colis c
   SET statut_logistique = 'livre',
       statut = 'livre',
       date_livraison_reelle = COALESCE(c.date_livraison_reelle, now()),
       updated_at = now()
  FROM public.tournees t
 WHERE c.tournee_id = t.tournee_id
   AND t.statut IN ('terminee','cloturee')
   AND c.statut_logistique NOT IN ('livre','retour');
