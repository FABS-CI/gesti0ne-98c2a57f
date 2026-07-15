
CREATE OR REPLACE FUNCTION public.annuler_paiement(_paiement_id uuid)
RETURNS public.paiements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_p public.paiements;
  v_fac record;
  v_total_paye numeric;
  v_nouveau_statut text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée pour annuler un paiement';
  END IF;

  SELECT * INTO v_p FROM public.paiements WHERE paiement_id = _paiement_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;
  IF v_p.statut = 'annule' THEN
    RAISE EXCEPTION 'Paiement déjà annulé';
  END IF;

  UPDATE public.paiements
     SET statut = 'annule',
         updated_at = now(),
         notes = COALESCE(notes,'') || E'\n[Annulé le ' || to_char(now(),'YYYY-MM-DD HH24:MI') || ']'
   WHERE paiement_id = _paiement_id
   RETURNING * INTO v_p;

  IF v_p.facture_id IS NOT NULL THEN
    SELECT * INTO v_fac FROM public.factures WHERE facture_id = v_p.facture_id FOR UPDATE;
    IF FOUND THEN
      v_total_paye := GREATEST(0, COALESCE(v_fac.montant_paye, 0) - COALESCE(v_p.montant, 0));
      IF v_total_paye >= COALESCE(v_fac.montant_total, 0) AND COALESCE(v_fac.montant_total,0) > 0 THEN
        v_nouveau_statut := 'payee';
      ELSIF v_total_paye > 0 THEN
        v_nouveau_statut := 'partielle';
      ELSE
        v_nouveau_statut := 'impayee';
      END IF;
      UPDATE public.factures
         SET montant_paye = v_total_paye,
             statut = v_nouveau_statut,
             updated_at = now()
       WHERE facture_id = v_fac.facture_id;
    END IF;
  END IF;

  RETURN v_p;
END $function$;

GRANT EXECUTE ON FUNCTION public.annuler_paiement(uuid) TO authenticated;
