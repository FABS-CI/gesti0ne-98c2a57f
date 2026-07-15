ALTER PUBLICATION supabase_realtime ADD TABLE public.colis_statut_historique;
ALTER PUBLICATION supabase_realtime ADD TABLE public.colis;
ALTER TABLE public.colis_statut_historique REPLICA IDENTITY FULL;
ALTER TABLE public.colis REPLICA IDENTITY FULL;