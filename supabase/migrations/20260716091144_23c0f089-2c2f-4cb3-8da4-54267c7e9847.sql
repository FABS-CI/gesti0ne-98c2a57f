
CREATE OR REPLACE FUNCTION public.exercice_actif_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT exercice_id FROM public.exercices_comptables
   WHERE statut = 'actif' OR statut = 'ouvert'
   ORDER BY date_debut DESC LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.exercice_actif_id() TO authenticated, service_role;
