-- Retire l'execution anonyme sur les fonctions SECURITY DEFINER internes
REVOKE EXECUTE ON FUNCTION public.track_user_action(_action_key text, _module text, _label text, _icon text, _href text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.sync_rbac_matrix() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_colis_sync_tournee_fn() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trigger_execution_log_purge() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recalc_tournee_from_colis(_date date) FROM PUBLIC, anon;
-- get_carton_public reste accessible aux anonymes (suivi carton public)
