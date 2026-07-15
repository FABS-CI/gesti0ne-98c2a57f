
CREATE OR REPLACE FUNCTION public.notifier_changement_statut_livraison()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ref text;
  v_client text;
  v_type text;
  v_titre text;
BEGIN
  IF NEW.nouveau_statut NOT IN (
    'assignee','en_route','deposee_gare','arrivee_destination',
    'retiree_client','livree','retour','anomalie'
  ) THEN
    RETURN NEW;
  END IF;

  SELECT c.reference, c.client_nom
    INTO v_ref, v_client
  FROM public.livraisons_commande lc
  JOIN public.commandes c ON c.commande_id = lc.commande_id
  WHERE lc.livraison_id = NEW.livraison_id;

  v_titre := 'Livraison ' || COALESCE(v_ref, '') || ' → ' || NEW.nouveau_statut::text;
  v_type := CASE
    WHEN NEW.nouveau_statut IN ('anomalie','retour') THEN 'warning'
    WHEN NEW.nouveau_statut IN ('livree','retiree_client') THEN 'success'
    ELSE 'info'
  END;

  INSERT INTO public.notifications(titre, message, type_notification, lu, date_notification)
  VALUES (
    v_titre,
    COALESCE('Client: '||v_client||'. ', '') || COALESCE(NEW.commentaire, ''),
    v_type,
    false,
    CURRENT_DATE
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notif_changement_statut_livraison ON public.livraison_commande_historique;
CREATE TRIGGER trg_notif_changement_statut_livraison
AFTER INSERT ON public.livraison_commande_historique
FOR EACH ROW EXECUTE FUNCTION public.notifier_changement_statut_livraison();
