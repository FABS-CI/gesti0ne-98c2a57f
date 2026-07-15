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

  -- Journal d'audit AVANT la suppression
  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (
    _user, _email, 'delete_commande_definitif', 'commandes', _commande_id::text,
    to_jsonb(_cmd),
    jsonb_build_object('motif', _motif, 'role', 'super_admin', 'reference', _cmd.reference)
  );

  -- Collecte des IDs liés
  SELECT array_agg(facture_id) INTO _facture_ids FROM public.factures WHERE commande_id = _commande_id;
  SELECT array_agg(bl_id) INTO _bl_ids FROM public.bons_livraison WHERE commande_id = _commande_id;

  -- Suppression des dépendances des factures
  IF _facture_ids IS NOT NULL THEN
    DELETE FROM public.paiements WHERE facture_id = ANY(_facture_ids);
    DELETE FROM public.fne_factures WHERE facture_id = ANY(_facture_ids);
    DELETE FROM public.bons_retour WHERE facture_id = ANY(_facture_ids);
    UPDATE public.retours SET facture_id = NULL WHERE facture_id = ANY(_facture_ids);
    DELETE FROM public.factures WHERE facture_id = ANY(_facture_ids);
  END IF;

  -- Suppression des dépendances des BL
  IF _bl_ids IS NOT NULL THEN
    DELETE FROM public.expeditions WHERE bl_id = ANY(_bl_ids);
    UPDATE public.livraisons_commande SET bl_id = NULL WHERE bl_id = ANY(_bl_ids);
    -- colis CASCADE via bl_id ; colis_statut_historique CASCADE via colis
    DELETE FROM public.bons_livraison WHERE bl_id = ANY(_bl_ids);
  END IF;

  -- Colis directement liés à la commande (non rattachés via BL)
  DELETE FROM public.colis WHERE commande_id = _commande_id;

  -- Proformas (proforma_lignes CASCADE)
  DELETE FROM public.proformas WHERE commande_id = _commande_id;

  -- Retours encore liés (retour_lignes CASCADE)
  DELETE FROM public.retours WHERE commande_id = _commande_id;

  -- Suivi logistique & livraisons (historique CASCADE)
  DELETE FROM public.livraisons_commande WHERE commande_id = _commande_id;
  DELETE FROM public.livraisons WHERE commande_id = _commande_id;
  DELETE FROM public.ordres_colisage WHERE commande_id = _commande_id;

  -- Transactions financières orphelines
  DELETE FROM public.transactions WHERE commande_id = _commande_id;

  -- Documents (PDF) éventuellement stockés
  DELETE FROM public.documents
    WHERE (metadata->>'commande_id') = _commande_id::text
       OR (metadata->>'reference') = _cmd.reference;

  -- Enfin la commande (commande_lignes CASCADE)
  DELETE FROM public.commandes WHERE commande_id = _commande_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.supprimer_commande_definitif(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supprimer_commande_definitif(uuid, text) TO authenticated;