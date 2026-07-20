-- Fix: assert_permission écrit dans rbac_audit_log lors d'un refus, ce qui nécessite VOLATILE
CREATE OR REPLACE FUNCTION public.assert_permission(_perm text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_permission_v2(auth.uid(), _perm) THEN
    INSERT INTO public.rbac_audit_log(user_id, action, details)
    VALUES (auth.uid(), 'permission_denied', jsonb_build_object('permission', _perm, 'source', 'rpc'));
    RAISE EXCEPTION 'Permission refusée: %', _perm USING ERRCODE = '42501';
  END IF;
END;
$$;