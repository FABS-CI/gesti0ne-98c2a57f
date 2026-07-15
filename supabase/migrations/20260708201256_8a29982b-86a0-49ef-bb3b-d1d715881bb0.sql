CREATE OR REPLACE FUNCTION public.supprimer_paiement_definitif(_paiement_id uuid, _motif text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ref text;
BEGIN
  IF NOT (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'directeur_general')) THEN
    RAISE EXCEPTION 'Accès refusé : réservé aux super-admins et directeurs généraux';
  END IF;

  IF _motif IS NULL OR length(trim(_motif)) = 0 THEN
    RAISE EXCEPTION 'Motif obligatoire';
  END IF;

  SELECT reference INTO v_ref
  FROM public.paiements
  WHERE paiement_id = _paiement_id;

  IF v_ref IS NULL THEN
    RAISE EXCEPTION 'Paiement introuvable';
  END IF;

  PERFORM set_config('app.allow_paiement_delete', 'on', true);

  DELETE FROM public.paiements
  WHERE paiement_id = _paiement_id;

  INSERT INTO public.audit_events (
    user_id,
    action,
    module,
    table_name,
    record_id,
    record_ref,
    metadata
  )
  VALUES (
    auth.uid(),
    'DELETE',
    'paiements',
    'paiements',
    _paiement_id::text,
    v_ref,
    jsonb_build_object(
      'motif', trim(_motif),
      'type', 'suppression_definitive'
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.supprimer_paiement_definitif(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supprimer_paiement_definitif(uuid, text) TO authenticated;