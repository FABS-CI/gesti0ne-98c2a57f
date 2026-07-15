DROP FUNCTION IF EXISTS public.supprimer_commande_definitif(uuid, text);

CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    _is_super_admin boolean;
    _liv_ids uuid[];
    _colis_ids uuid[];
    _bl_ids uuid[];
    _facture_ids uuid[];
    _proforma_ids uuid[];
BEGIN
    SELECT public.has_role(auth.uid(), 'super_admin'::app_role) INTO _is_super_admin;
    IF NOT _is_super_admin THEN
        RAISE EXCEPTION 'Accès refusé : super_admin uniquement';
    END IF;

    SELECT array_agg(id) INTO _liv_ids FROM public.livraisons_commande WHERE commande_id = _commande_id;
    SELECT array_agg(id) INTO _colis_ids FROM public.colis WHERE commande_id = _commande_id;
    SELECT array_agg(id) INTO _bl_ids FROM public.bons_livraison WHERE commande_id = _commande_id;
    SELECT array_agg(id) INTO _facture_ids FROM public.factures WHERE commande_id = _commande_id;
    SELECT array_agg(id) INTO _proforma_ids FROM public.proformas WHERE commande_id = _commande_id;

    IF _liv_ids IS NOT NULL THEN
        DELETE FROM public.livraison_commande_historique WHERE livraison_id = ANY(_liv_ids);
        DELETE FROM public.livraisons_commande WHERE id = ANY(_liv_ids);
    END IF;
    IF _colis_ids IS NOT NULL THEN
        DELETE FROM public.colis_statut_historique WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colis_lignes WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colis WHERE id = ANY(_colis_ids);
    END IF;
    IF _bl_ids IS NOT NULL THEN
        DELETE FROM public.bons_livraison WHERE id = ANY(_bl_ids);
    END IF;
    IF _facture_ids IS NOT NULL THEN
        DELETE FROM public.paiements WHERE facture_id = ANY(_facture_ids);
        DELETE FROM public.factures WHERE id = ANY(_facture_ids);
    END IF;
    IF _proforma_ids IS NOT NULL THEN
        DELETE FROM public.proforma_lignes WHERE proforma_id = ANY(_proforma_ids);
        DELETE FROM public.proformas WHERE id = ANY(_proforma_ids);
    END IF;

    DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;
    DELETE FROM public.commandes WHERE id = _commande_id;

    INSERT INTO public.audit_events(event_type, entite, entite_id, user_id, metadata)
    VALUES ('commande.supprimee_definitivement', 'commande', _commande_id, auth.uid(),
            jsonb_build_object('motif', _motif));
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.supprimer_commande_definitif(uuid, text) FROM PUBLIC, anon;