
CREATE OR REPLACE FUNCTION public.compta_balance(
  p_from date DEFAULT NULL,
  p_to date DEFAULT NULL,
  p_exercice_id uuid DEFAULT NULL
)
RETURNS TABLE (
  compte text,
  compte_libelle text,
  debit numeric,
  credit numeric,
  solde numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    l.compte,
    MIN(l.compte_libelle) AS compte_libelle,
    COALESCE(SUM(l.debit), 0) AS debit,
    COALESCE(SUM(l.credit), 0) AS credit,
    COALESCE(SUM(l.debit), 0) - COALESCE(SUM(l.credit), 0) AS solde
  FROM public.ecriture_lignes l
  JOIN public.ecritures_comptables e ON e.ecriture_id = l.ecriture_id
  WHERE (p_from IS NULL OR e.date_ecriture >= p_from)
    AND (p_to   IS NULL OR e.date_ecriture <= p_to)
    AND (p_exercice_id IS NULL OR e.exercice_id = p_exercice_id)
  GROUP BY l.compte
  ORDER BY l.compte;
$$;

GRANT EXECUTE ON FUNCTION public.compta_balance(date, date, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.compta_balance(date, date, uuid) TO service_role;
