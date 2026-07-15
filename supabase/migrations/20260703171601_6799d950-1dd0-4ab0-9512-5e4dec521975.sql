-- Durcissement ciblé des fonctions SECURITY DEFINER.
-- Les fonctions gardées pour l'application restent appelables par les utilisateurs connectés.
-- Les fonctions internes restent utilisables par les triggers et par les fonctions backend propriétaires.

REVOKE EXECUTE ON FUNCTION public.get_carton_public(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_carton_public(uuid) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.assigner_livraisons_tournee(uuid,uuid,jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.can_choose_depot(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.changer_statut_colis(uuid,text,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.changer_statut_livraison(uuid,public.statut_livraison_cmd,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.changer_statut_livraison_commande(uuid,public.statut_livraison_cmd,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.colisage_logistique_deja_pris(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.creer_livraison_commande(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.creer_notification(text,text,text,text,text,uuid,text,text,public.app_role,uuid,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.deverrouiller_colisage(uuid,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.enregistrer_livraison_partielle(uuid,integer,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.has_permission_v2(uuid,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.merge_clients(uuid,uuid[]) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.rbac_role_ancestors(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.recalc_commande(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.recalculer_livraison_commande(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.refresh_produit_stock(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.refresh_specimen_totaux(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.resolve_depot_sortie(uuid,text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.signaler_anomalie_livraison(uuid,text) FROM authenticated;

DROP POLICY IF EXISTS perf_log_insert_auth ON public.perf_query_log;
CREATE POLICY perf_log_insert_auth
ON public.perf_query_log
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);