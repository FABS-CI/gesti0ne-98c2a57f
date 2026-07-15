-- Audit trail on sales conversions
CREATE OR REPLACE FUNCTION public.convertir_proforma_en_commande(_proforma_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pro RECORD;
  v_commande_id UUID;
  v_uid UUID := (SELECT auth.uid());
  v_email TEXT;
BEGIN
  IF NOT public.is_staff(v_uid) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT * INTO v_pro FROM public.proformas WHERE proforma_id = _proforma_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proforma introuvable'; END IF;
  IF v_pro.statut = 'acceptee' THEN RAISE EXCEPTION 'Proforma déjà convertie'; END IF;

  INSERT INTO public.commandes (
    client_id, client_nom, statut, date_commande, remise,
    montant_total, notes, exercice_id
  ) VALUES (
    v_pro.client_id, v_pro.client_nom, 'validee', CURRENT_DATE, 0,
    COALESCE(v_pro.montant_total, 0),
    'Issue de la proforma ' || v_pro.reference,
    v_pro.exercice_id
  ) RETURNING commande_id INTO v_commande_id;

  INSERT INTO public.commande_lignes (
    commande_id, produit_id, designation, quantite, prix_unitaire, total_ligne
  )
  SELECT v_commande_id, produit_id, designation, quantite, prix_unitaire, total_ligne
  FROM public.proforma_lignes WHERE proforma_id = _proforma_id;

  UPDATE public.proformas SET statut = 'acceptee' WHERE proforma_id = _proforma_id;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id, new_values)
  VALUES (
    v_uid, v_email, 'convertir_proforma_en_commande', 'commandes', v_commande_id::text,
    jsonb_build_object(
      'proforma_id', _proforma_id,
      'proforma_reference', v_pro.reference,
      'commande_id', v_commande_id,
      'statut', 'validee',
      'montant_total', COALESCE(v_pro.montant_total, 0)
    )
  );

  RETURN v_commande_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.convertir_commande_en_bl(
  _commande_id UUID,
  _nb_colis INT,
  _poids_total NUMERIC DEFAULT NULL,
  _transporteur TEXT DEFAULT NULL,
  _adresse_livraison TEXT DEFAULT NULL,
  _signataire TEXT DEFAULT NULL,
  _date_livraison DATE DEFAULT NULL,
  _decrementer_stock BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (bl_id UUID, reference TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cmd RECORD;
  v_bl_id UUID;
  v_bl_ref TEXT;
  v_ordre_ref TEXT;
  v_poids_par_colis NUMERIC;
  v_stamp TEXT;
  v_uid UUID := (SELECT auth.uid());
  v_email TEXT;
BEGIN
  IF NOT public.is_staff(v_uid) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;
  IF _nb_colis < 1 THEN
    RAISE EXCEPTION 'Au moins 1 colis requis';
  END IF;

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  v_stamp := to_char(clock_timestamp(), 'YYYYMMDD-HH24MISSMS');
  v_bl_ref := 'BL-' || v_stamp;
  v_ordre_ref := 'OC-' || v_stamp;

  INSERT INTO public.bons_livraison (
    reference, commande_id, client_id, date_emission, date_livraison,
    statut, transporteur, adresse_livraison, signataire, montant_total, notes,
    exercice_id
  ) VALUES (
    v_bl_ref, _commande_id, v_cmd.client_id, CURRENT_DATE,
    COALESCE(_date_livraison, CURRENT_DATE),
    'a_preparer', _transporteur, _adresse_livraison, _signataire,
    COALESCE(v_cmd.montant_total, 0),
    'BL issu de la commande ' || v_cmd.reference || ' — ' || _nb_colis || ' colis',
    v_cmd.exercice_id
  ) RETURNING bons_livraison.bl_id INTO v_bl_id;

  INSERT INTO public.ordres_colisage (
    reference, commande_id, nb_colis, poids_total, statut, notes
  ) VALUES (
    v_ordre_ref, _commande_id, _nb_colis, _poids_total,
    'prepare', 'Colisage pour ' || v_bl_ref
  );

  v_poids_par_colis := CASE
    WHEN _poids_total IS NOT NULL AND _nb_colis > 0 THEN ROUND(_poids_total / _nb_colis, 2)
    ELSE 0
  END;

  INSERT INTO public.colis (
    reference, destinataire, contenu, poids, transporteur,
    date_envoi, statut, statut_logistique, bl_id, commande_id, numero_carton, nb_cartons
  )
  SELECT
    v_bl_ref || '-C' || LPAD(i::text, 2, '0'),
    v_cmd.client_nom,
    'Commande ' || v_cmd.reference || ' (' || i || '/' || _nb_colis || ')',
    v_poids_par_colis,
    _transporteur,
    COALESCE(_date_livraison, CURRENT_DATE),
    'prepare',
    'a_expedier',
    v_bl_id,
    _commande_id,
    i,
    _nb_colis
  FROM generate_series(1, _nb_colis) AS i;

  IF _decrementer_stock THEN
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif)
    SELECT
      cl.produit_id, 'sortie', cl.quantite,
      'Livraison ' || v_bl_ref || ' — ' || cl.designation
    FROM public.commande_lignes cl
    WHERE cl.commande_id = _commande_id AND cl.produit_id IS NOT NULL;
  END IF;

  UPDATE public.commandes SET statut = 'livree' WHERE commande_id = _commande_id;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id, new_values)
  VALUES (
    v_uid, v_email, 'convertir_commande_en_bl', 'bons_livraison', v_bl_id::text,
    jsonb_build_object(
      'commande_id', _commande_id,
      'commande_reference', v_cmd.reference,
      'bl_id', v_bl_id,
      'bl_reference', v_bl_ref,
      'ordre_colisage_reference', v_ordre_ref,
      'nb_colis', _nb_colis,
      'poids_total', _poids_total,
      'montant_total', COALESCE(v_cmd.montant_total, 0),
      'statut_commande', 'livree',
      'decrement_stock', _decrementer_stock
    )
  );

  RETURN QUERY SELECT v_bl_id, v_bl_ref;
END;
$$;

GRANT EXECUTE ON FUNCTION public.convertir_proforma_en_commande(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.convertir_commande_en_bl(UUID, INT, NUMERIC, TEXT, TEXT, TEXT, DATE, BOOLEAN) TO authenticated;