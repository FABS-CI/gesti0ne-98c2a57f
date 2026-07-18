
CREATE OR REPLACE FUNCTION public.supprimer_retour_definitif(_retour_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean;
  v_statut text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = v_uid AND role = 'super_admin'
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Suppression réservée aux super administrateurs';
  END IF;

  SELECT statut INTO v_statut
  FROM public.retours
  WHERE retour_id = _retour_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Retour introuvable';
  END IF;

  -- Inverse les effets si le retour est toujours "accepté"
  IF v_statut IS DISTINCT FROM 'annule' THEN
    BEGIN
      PERFORM public.annuler_retour(_retour_id);
    EXCEPTION WHEN OTHERS THEN
      -- Le super_admin force malgré tout la suppression
      NULL;
    END;
  END IF;

  DELETE FROM public.retour_lignes WHERE retour_id = _retour_id;
  DELETE FROM public.retours WHERE retour_id = _retour_id;
END;
$$;

REVOKE ALL ON FUNCTION public.supprimer_retour_definitif(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.supprimer_retour_definitif(uuid) TO authenticated;
