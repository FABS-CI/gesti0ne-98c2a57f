-- À la clôture d'une tournée, si des coûts ont été saisis (cout_total > 0),
-- on garantit que la ligne apparaisse automatiquement dans "Coûts logistiques"
-- avec le statut "en_attente" (attente de validation comptable).
CREATE OR REPLACE FUNCTION public.cloturer_tournee(_tournee_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total numeric;
  v_statut text;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'tournees.cloturer') THEN
    RAISE EXCEPTION 'Accès refusé : permission tournees.cloturer requise' USING ERRCODE = '42501';
  END IF;

  PERFORM public.finaliser_tournee_interne(_tournee_id);

  UPDATE public.tournees SET statut = 'terminee', updated_at = now()
  WHERE tournee_id = _tournee_id;

  -- Calcul du total et bascule automatique du statut de validation
  SELECT COALESCE(cout_total, 0), validation_statut INTO v_total, v_statut
  FROM public.tournees WHERE tournee_id = _tournee_id;

  IF v_total > 0 AND (v_statut IS NULL OR v_statut IN ('brouillon')) THEN
    UPDATE public.tournees
       SET validation_statut = 'en_attente', updated_at = now()
     WHERE tournee_id = _tournee_id;

    INSERT INTO public.couts_logistiques_audit(tournee_id, action, actor, actor_email, commentaire)
    VALUES (_tournee_id, 'soumission_auto', auth.uid(),
            (SELECT email FROM auth.users WHERE id = auth.uid()),
            'Soumission automatique à la clôture de la tournée');
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.cloturer_tournee(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cloturer_tournee(uuid) TO authenticated, service_role;