
CREATE OR REPLACE FUNCTION public._resolve_exercice_id(_d date)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT exercice_id FROM public.exercices_comptables
  WHERE _d BETWEEN date_debut AND date_fin
  ORDER BY is_actif DESC, date_debut DESC LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.enregistrer_paiement(_payload jsonb)
 RETURNS SETOF paiements LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('PAI', 'public.paiements', 'reference');
  v_facture_id uuid := NULLIF(_payload->>'facture_id','')::uuid;
  v_montant numeric := COALESCE((_payload->>'montant')::numeric, 0);
  v_client_nom text;
  v_new_paye numeric; v_total numeric;
  v_date date := COALESCE((_payload->>'date_paiement')::date, current_date);
  v_ex uuid;
BEGIN
  IF v_facture_id IS NULL THEN RAISE EXCEPTION 'facture_id obligatoire'; END IF;
  SELECT client_nom, montant_total, montant_paye INTO v_client_nom, v_total, v_new_paye
    FROM public.factures WHERE facture_id = v_facture_id;
  IF v_total IS NULL THEN RAISE EXCEPTION 'Facture introuvable'; END IF;

  v_ex := public._resolve_exercice_id(v_date);
  IF v_ex IS NULL THEN
    SELECT exercice_id INTO v_ex FROM public.exercices_comptables WHERE is_actif ORDER BY date_debut DESC LIMIT 1;
  END IF;

  INSERT INTO public.paiements(
    reference, facture_id, client_nom, date_paiement, montant, mode_paiement,
    statut, notes, reference_paiement, banque, num_transaction, observations, cree_par, exercice_id
  ) VALUES (
    v_ref, v_facture_id, v_client_nom, v_date, v_montant,
    COALESCE(_payload->>'mode_paiement','especes'), 'valide',
    _payload->>'notes', _payload->>'reference_paiement', _payload->>'banque',
    _payload->>'num_transaction', _payload->>'observations', auth.uid(), v_ex
  ) RETURNING paiement_id INTO v_id;

  v_new_paye := COALESCE(v_new_paye,0) + v_montant;
  UPDATE public.factures SET
    montant_paye = v_new_paye,
    statut = CASE WHEN v_new_paye >= v_total THEN 'payee' WHEN v_new_paye > 0 THEN 'partielle' ELSE 'impayee' END
  WHERE facture_id = v_facture_id;

  RETURN QUERY SELECT * FROM public.paiements WHERE paiement_id = v_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.convertir_proforma_en_commande(_proforma_id uuid)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('CMD', 'public.commandes', 'reference');
  v_p public.proformas;
  v_ex uuid;
BEGIN
  SELECT * INTO v_p FROM public.proformas WHERE proforma_id = _proforma_id;
  IF v_p.proforma_id IS NULL THEN RAISE EXCEPTION 'Proforma introuvable'; END IF;

  v_ex := public._resolve_exercice_id(current_date);
  IF v_ex IS NULL THEN
    SELECT exercice_id INTO v_ex FROM public.exercices_comptables WHERE is_actif ORDER BY date_debut DESC LIMIT 1;
  END IF;

  INSERT INTO public.commandes(reference, client_id, client_nom, statut, montant_total, montant_ttc, net_a_payer, created_by, exercice_id)
  VALUES (v_ref, v_p.client_id, v_p.client_nom, 'brouillon', v_p.montant_total, v_p.montant_total, v_p.montant_total, auth.uid(), v_ex)
  RETURNING commande_id INTO v_id;

  INSERT INTO public.commande_lignes(commande_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne, total_ht_ligne)
  SELECT v_id, produit_id, reference_produit, COALESCE(designation,''), COALESCE(quantite,0)::int, COALESCE(prix_unitaire,0), COALESCE(total_ligne,0), COALESCE(total_ligne,0)
  FROM public.proforma_lignes WHERE proforma_id = _proforma_id;

  UPDATE public.proformas SET statut = 'convertie', commande_id = v_id WHERE proforma_id = _proforma_id;
  RETURN v_id;
END; $function$;
