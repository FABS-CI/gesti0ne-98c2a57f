
-- 1) Empêche définitivement les surpaiements au niveau table.
ALTER TABLE public.factures
  DROP CONSTRAINT IF EXISTS factures_montant_paye_check;
ALTER TABLE public.factures
  ADD CONSTRAINT factures_montant_paye_check
  CHECK (montant_paye >= 0 AND montant_paye <= montant_total);

-- 2) Supprime l'ancienne signature d'annulation (sans raison, sans audit).
DROP FUNCTION IF EXISTS public.annuler_paiement(uuid);

-- 3) Défense en profondeur dans enregistrer_paiement : refuse tout montant qui
--    dépasse le solde restant de la facture.
CREATE OR REPLACE FUNCTION public.enregistrer_paiement(_payload jsonb)
 RETURNS paiements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_p public.paiements;
  v_fac record;
  v_montant numeric;
  v_solde numeric;
  v_total_paye numeric;
  v_nouveau_statut text;
  v_notes text;
  v_ref text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée pour enregistrer un paiement';
  END IF;

  v_montant := COALESCE((_payload->>'montant')::numeric, 0);
  IF v_montant <= 0 THEN RAISE EXCEPTION 'Le montant doit être positif'; END IF;
  IF (_payload->>'facture_id') IS NULL OR _payload->>'facture_id' = '' THEN
    RAISE EXCEPTION 'Facture obligatoire';
  END IF;

  SELECT * INTO v_fac FROM public.factures WHERE facture_id=(_payload->>'facture_id')::uuid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Facture introuvable'; END IF;

  v_solde := GREATEST(0, COALESCE(v_fac.montant_total,0) - COALESCE(v_fac.montant_paye,0));
  IF v_montant > v_solde THEN
    RAISE EXCEPTION 'Le montant (%.2f) dépasse le solde restant (%.2f) de la facture %',
      v_montant, v_solde, v_fac.reference;
  END IF;

  v_notes := COALESCE(_payload->>'observations','');
  IF (_payload->>'banque') IS NOT NULL AND _payload->>'banque' <> '' THEN
    v_notes := v_notes || E'\nBanque: ' || (_payload->>'banque');
  END IF;
  IF (_payload->>'num_transaction') IS NOT NULL AND _payload->>'num_transaction' <> '' THEN
    v_notes := v_notes || E'\nN° transaction: ' || (_payload->>'num_transaction');
  END IF;
  IF (_payload->>'reference_paiement') IS NOT NULL AND _payload->>'reference_paiement' <> '' THEN
    v_notes := v_notes || E'\nRéférence: ' || (_payload->>'reference_paiement');
  END IF;

  v_ref := 'PAY-'||to_char(now(),'YYYYMMDD-HH24MISS');

  INSERT INTO public.paiements(reference, facture_id, client_nom, date_paiement, montant, mode_paiement, statut, notes)
  VALUES(v_ref, v_fac.facture_id, v_fac.client_nom,
    COALESCE((_payload->>'date_paiement')::date, current_date),
    v_montant,
    COALESCE(_payload->>'mode_paiement','especes'),
    'valide',
    NULLIF(trim(v_notes), ''))
  RETURNING * INTO v_p;

  v_total_paye := COALESCE(v_fac.montant_paye, 0) + v_montant;
  IF v_total_paye >= COALESCE(v_fac.montant_total, 0) THEN
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

  RETURN v_p;
END $function$;
