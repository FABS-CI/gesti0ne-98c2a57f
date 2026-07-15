
CREATE OR REPLACE FUNCTION public.calcul_solde_client(_client_id uuid, _exercice_id uuid)
RETURNS numeric
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_report numeric := 0;
  v_factures numeric := 0;
  v_paiements numeric := 0;
  v_retours numeric := 0;
BEGIN
  SELECT COALESCE(SUM(montant), 0) INTO v_report
  FROM public.soldes_ouverture_clients
  WHERE client_id = _client_id AND exercice_id = _exercice_id;

  SELECT COALESCE(SUM(montant_total), 0) INTO v_factures
  FROM public.factures
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut <> 'annulee';

  SELECT COALESCE(SUM(p.montant), 0) INTO v_paiements
  FROM public.paiements p
  JOIN public.factures f ON f.facture_id = p.facture_id
  WHERE f.client_id = _client_id
    AND p.exercice_id = _exercice_id
    AND p.statut = 'valide';

  SELECT COALESCE(SUM(montant), 0) INTO v_retours
  FROM public.retours
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut IN ('accepte', 'valide');

  RETURN v_report + v_factures - v_paiements - v_retours;
END;
$function$;
