
CREATE OR REPLACE FUNCTION public.trg_notif_tournees()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.creer_notification('Nouvelle tournée — '||COALESCE(NEW.reference,''),
      COALESCE('Date: '||NEW.date_tournee::text,''),'info','tournees','tournees',NEW.tournee_id,NEW.reference,
      '/tournees','service_logistique',NULL,'normale');
  ELSIF TG_OP='UPDATE' AND OLD.livreur_id IS DISTINCT FROM NEW.livreur_id AND NEW.livreur_id IS NOT NULL THEN
    PERFORM public.creer_notification('Livreur affecté — '||COALESCE(NEW.reference,''),
      'Un livreur a été affecté à la tournée','info','tournees','tournees',NEW.tournee_id,NEW.reference,
      '/tournees','service_logistique',NULL,'normale');
  END IF;
  RETURN NEW;
END $function$;
