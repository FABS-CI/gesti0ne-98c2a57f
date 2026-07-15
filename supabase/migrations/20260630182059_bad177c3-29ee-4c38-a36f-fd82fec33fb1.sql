CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  _cmd public.commandes%ROWTYPE;
  _user uuid := auth.uid();
  _email text;
  _facture_ids uuid[];
  _bl_ids uuid[];
BEGIN
  IF _user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO _cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bon de commande introuvable' USING ERRCODE = 'P0002';
  END IF;

  SELECT email INTO _email FROM auth.users WHERE id = _user;

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (
    _user, _email, 'delete_commande_definitif', 'commandes', _commande_id::text,
    to_jsonb(_cmd),
    jsonb_build_object('motif', _motif, 'role', 'super_admin', 'reference', _cmd.reference)
  );

  SELECT array_agg(facture_id) INTO _facture_ids FROM public.factures WHERE commande_id = _commande_id;
  SELECT array_agg(bl_id) INTO _bl_ids FROM public.bons_livraison WHERE commande_id = _commande_id;

  IF _facture_ids IS NOT NULL THEN
    DELETE FROM public.paiements WHERE facture_id = ANY(_facture_ids);
    DELETE FROM public.fne_factures WHERE facture_id = ANY(_facture_ids);
    DELETE FROM public.bons_retour WHERE facture_id = ANY(_facture_ids);
    UPDATE public.retours SET facture_id = NULL WHERE facture_id = ANY(_facture_ids);
    DELETE FROM public.factures WHERE facture_id = ANY(_facture_ids);
  END IF;

  IF _bl_ids IS NOT NULL THEN
    DELETE FROM public.expeditions WHERE bl_id = ANY(_bl_ids);
    UPDATE public.livraisons_commande SET bl_id = NULL WHERE bl_id = ANY(_bl_ids);
    DELETE FROM public.bons_livraison WHERE bl_id = ANY(_bl_ids);
  END IF;

  DELETE FROM public.colis WHERE commande_id = _commande_id;
  DELETE FROM public.proformas WHERE commande_id = _commande_id;
  DELETE FROM public.retours WHERE commande_id = _commande_id;
  DELETE FROM public.livraisons_commande WHERE commande_id = _commande_id;
  DELETE FROM public.livraisons WHERE commande_id = _commande_id;
  DELETE FROM public.ordres_colisage WHERE commande_id = _commande_id;
  DELETE FROM public.transactions WHERE commande_id = _commande_id;

  DELETE FROM public.commandes WHERE commande_id = _commande_id;
END;
$function$;