CREATE OR REPLACE FUNCTION public.exercices_comparatif(_exercice_ids uuid[])
RETURNS TABLE (
  exercice_id uuid,
  ca numeric,
  encaisse numeric,
  achats numeric,
  nb_commandes bigint,
  nb_factures bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH ex AS (
    SELECT unnest(_exercice_ids) AS exercice_id
  )
  SELECT
    ex.exercice_id,
    COALESCE((SELECT SUM(COALESCE(montant_total,0)) FROM factures f WHERE f.exercice_id = ex.exercice_id), 0) AS ca,
    COALESCE((SELECT SUM(COALESCE(montant,0)) FROM paiements p WHERE p.exercice_id = ex.exercice_id AND p.statut IS DISTINCT FROM 'annule'), 0) AS encaisse,
    COALESCE((SELECT SUM(COALESCE(montant,0)) FROM achats a WHERE a.exercice_id = ex.exercice_id), 0) AS achats,
    COALESCE((SELECT COUNT(*) FROM commandes c WHERE c.exercice_id = ex.exercice_id), 0) AS nb_commandes,
    COALESCE((SELECT COUNT(*) FROM factures f WHERE f.exercice_id = ex.exercice_id), 0) AS nb_factures
  FROM ex;
$$;

GRANT EXECUTE ON FUNCTION public.exercices_comparatif(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exercices_comparatif(uuid[]) TO service_role;