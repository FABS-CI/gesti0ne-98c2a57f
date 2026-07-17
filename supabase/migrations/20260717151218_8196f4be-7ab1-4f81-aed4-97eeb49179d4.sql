
CREATE OR REPLACE FUNCTION public.generer_proforma_commande(_commande_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pid uuid;
  v_ref text := public._next_ref('PRO', 'public.proformas', 'reference');
  v_cmd public.commandes;
  v_client_nom text;
BEGIN
  PERFORM public.assert_permission('commandes.generer_proforma');

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF v_cmd.commande_id IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  v_client_nom := COALESCE(NULLIF(v_cmd.client_nom,''), (SELECT nom FROM public.clients WHERE client_id = v_cmd.client_id));

  INSERT INTO public.proformas(reference, client_id, client_nom, commande_id, date_proforma, date_validite, montant_total, statut, notes)
  VALUES (v_ref, v_cmd.client_id, v_client_nom, _commande_id, current_date, current_date + 30, v_cmd.montant_total, 'emise', 'Proforma générée depuis '||v_cmd.reference)
  RETURNING proforma_id INTO v_pid;

  INSERT INTO public.proforma_lignes(proforma_id, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne)
  SELECT v_pid, produit_id, reference_produit, designation, quantite, prix_unitaire, total_ligne
  FROM public.commande_lignes WHERE commande_id = _commande_id;

  RETURN jsonb_build_object('proforma_id', v_pid, 'reference', v_ref);
END; $function$;

UPDATE public.proformas p
SET client_nom = COALESCE(NULLIF(c.client_nom,''), cl.nom)
FROM public.commandes c
LEFT JOIN public.clients cl ON cl.client_id = c.client_id
WHERE p.commande_id = c.commande_id
  AND (p.client_nom IS NULL OR p.client_nom = '');

UPDATE public.proformas p
SET client_nom = cl.nom
FROM public.clients cl
WHERE p.client_id = cl.client_id
  AND (p.client_nom IS NULL OR p.client_nom = '');
