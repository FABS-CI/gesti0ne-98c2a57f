CREATE OR REPLACE FUNCTION public.propagate_tournee_statut()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    IF NEW.statut IN ('en_cours','terminee','cloturee') THEN
      UPDATE public.colis
         SET statut_logistique = 'en_transit',
             statut = CASE WHEN statut IN ('en_preparation','prete') THEN 'expedie' ELSE statut END,
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut_logistique NOT IN ('livre','retour');
      UPDATE public.livraisons_commande
         SET statut = 'en_cours_livraison'::statut_livraison_cmd,
             heure_depart = COALESCE(heure_depart, now()),
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut NOT IN ('livree'::statut_livraison_cmd, 'annulee'::statut_livraison_cmd);
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;