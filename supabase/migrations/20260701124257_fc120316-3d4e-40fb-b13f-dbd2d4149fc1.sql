REVOKE EXECUTE ON FUNCTION public.colisage_logistique_deja_pris(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.annuler_colisage(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.supprimer_colisage(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.colisage_logistique_deja_pris(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.annuler_colisage(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.supprimer_colisage(uuid, text) TO authenticated, service_role;