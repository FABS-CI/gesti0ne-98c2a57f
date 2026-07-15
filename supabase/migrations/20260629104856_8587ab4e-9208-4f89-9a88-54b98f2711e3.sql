-- Fix 1: Restrict fne_settings reads to financial roles
DROP POLICY IF EXISTS "auth read fne_settings" ON public.fne_settings;
CREATE POLICY "finance read fne_settings" ON public.fne_settings
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','comptable']::app_role[]));

-- Fix 2: Restrict historique_envois reads to staff only
DROP POLICY IF EXISTS "auth read historique_envois" ON public.historique_envois;
CREATE POLICY "staff read historique_envois" ON public.historique_envois
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

-- Fix 3: Add staff role guards to transfer RPC functions
CREATE OR REPLACE FUNCTION public.executer_transfert(_transfert_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  t record;
  l record;
BEGIN
  IF NOT public.is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;

  SELECT * INTO t FROM public.transferts WHERE transfert_id = _transfert_id FOR UPDATE;
  IF t IS NULL THEN RAISE EXCEPTION 'Transfert introuvable'; END IF;
  IF t.statut <> 'brouillon' THEN RAISE EXCEPTION 'Transfert déjà traité (%)', t.statut; END IF;

  FOR l IN SELECT * FROM public.transfert_lignes WHERE transfert_id = _transfert_id LOOP
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
      VALUES (l.produit_id, 'transfert_sortie', l.quantite,
              'Transfert ' || t.numero, t.depot_source_id);
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
      VALUES (l.produit_id, 'transfert_entree', l.quantite,
              'Transfert ' || t.numero, t.depot_destination_id);
  END LOOP;

  UPDATE public.transferts
    SET statut = 'expedie', date_expedition = now(), date_reception = now()
    WHERE transfert_id = _transfert_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.receptionner_transfert(_transfert_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;
  UPDATE public.transferts SET statut = 'recu', date_reception = now()
    WHERE transfert_id = _transfert_id AND statut = 'expedie';
END;
$function$;

CREATE OR REPLACE FUNCTION public.annuler_transfert(_transfert_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;
  UPDATE public.transferts SET statut = 'annule'
    WHERE transfert_id = _transfert_id AND statut = 'brouillon';
END;
$function$;