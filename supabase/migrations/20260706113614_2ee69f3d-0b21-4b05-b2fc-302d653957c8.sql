
-- Lot 3 — Post-validation effets pour les retours clients

-- 1) annuler_retour : réintègre la logique de stock inverse et notifie
CREATE OR REPLACE FUNCTION public.annuler_retour(_retour_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  r public.retours;
  l record;
  v_actuel int;
BEGIN
  SELECT * INTO r FROM public.retours WHERE retour_id = _retour_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Retour introuvable';
  END IF;
  IF r.statut = 'annule' THEN
    RETURN;
  END IF;

  -- Reversal du stock ligne à ligne (uniquement pour les lignes remises en stock)
  IF r.depot_id IS NOT NULL THEN
    FOR l IN
      SELECT produit_id, quantite, motif
      FROM public.retour_lignes
      WHERE retour_id = _retour_id
        AND produit_id IS NOT NULL
        AND remise_en_stock = true
    LOOP
      SELECT quantite INTO v_actuel
      FROM public.stocks_depots
      WHERE produit_id = l.produit_id AND depot_id = r.depot_id
      FOR UPDATE;

      IF v_actuel IS NOT NULL AND v_actuel >= l.quantite THEN
        PERFORM public.ajuster_stock_depot(
          l.produit_id, r.depot_id, v_actuel - l.quantite,
          'Annulation retour ' || COALESCE(r.numero, r.reference),
          'annulation_retour', r.retour_id, COALESCE(r.numero, r.reference),
          'retours', l.motif
        );
      END IF;
    END LOOP;
  END IF;

  UPDATE public.retours
     SET statut = 'annule', updated_at = now()
   WHERE retour_id = _retour_id;

  -- Notification
  INSERT INTO public.notifications(titre, message, type_notification, module,
    document_type, document_id, document_reference, lien, priorite, role_cible)
  VALUES(
    'Retour annulé',
    'Le retour ' || COALESCE(r.numero, r.reference) || ' a été annulé.',
    'warning', 'retours', 'retour', r.retour_id,
    COALESCE(r.numero, r.reference), '/retours/' || r.retour_id::text,
    'normale', 'gestionnaire_stock'
  );
END
$function$;

-- 2) Trigger de notification à la création d'un retour accepté
CREATE OR REPLACE FUNCTION public.trg_retour_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.statut = 'accepte' THEN
    INSERT INTO public.notifications(titre, message, type_notification, module,
      document_type, document_id, document_reference, lien, priorite, role_cible)
    VALUES(
      'Nouveau retour client',
      'Retour ' || COALESCE(NEW.numero, NEW.reference)
        || ' — ' || COALESCE(NEW.etablissement, NEW.client_nom, 'client')
        || ' (' || NEW.total_quantite || ' unités)',
      'info', 'retours', 'retour', NEW.retour_id,
      COALESCE(NEW.numero, NEW.reference),
      '/retours/' || NEW.retour_id::text,
      'normale', 'gestionnaire_stock'
    );
  END IF;
  RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS trg_retour_notify ON public.retours;
CREATE TRIGGER trg_retour_notify
  AFTER INSERT ON public.retours
  FOR EACH ROW EXECUTE FUNCTION public.trg_retour_notify();

-- 3) Index utiles pour les futures jointures documentaires
CREATE INDEX IF NOT EXISTS idx_retours_facture_id ON public.retours(facture_id);
CREATE INDEX IF NOT EXISTS idx_retours_commande_id ON public.retours(commande_id);
