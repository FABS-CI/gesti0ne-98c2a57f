CREATE OR REPLACE FUNCTION public.supprimer_paiement_definitif(_paiement_id uuid, _motif text DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    _is_super_admin boolean;
    _ref text;
BEGIN
    SELECT public.has_role(auth.uid(), 'super_admin'::app_role) INTO _is_super_admin;
    IF NOT _is_super_admin THEN
        RAISE EXCEPTION 'Accès refusé : super_admin uniquement';
    END IF;

    SELECT reference INTO _ref FROM public.paiements WHERE paiement_id = _paiement_id;
    IF _ref IS NULL THEN
        RAISE EXCEPTION 'Paiement introuvable';
    END IF;

    PERFORM set_config('app.allow_paiement_delete', 'on', true);
    DELETE FROM public.paiements WHERE paiement_id = _paiement_id;

    INSERT INTO public.audit_events(event_type, entite, entite_id, user_id, metadata)
    VALUES ('paiement.supprime_definitivement', 'paiement', _paiement_id, auth.uid(),
            jsonb_build_object('reference', _ref, 'motif', _motif));
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.supprimer_paiement_definitif(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supprimer_paiement_definitif(uuid, text) TO authenticated;