
REVOKE EXECUTE ON FUNCTION public.convertir_commande_en_bl(uuid, integer, numeric, text, text, text, date, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.convertir_proforma_en_commande(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_lignes_retournables(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.notifier_points_expirants() FROM anon;
REVOKE EXECUTE ON FUNCTION public.purger_anciennes_sauvegardes(text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.renumber_employes_matricules() FROM anon;
REVOKE EXECUTE ON FUNCTION public.restore_employe(uuid, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.soft_delete_employe(uuid) FROM anon;
