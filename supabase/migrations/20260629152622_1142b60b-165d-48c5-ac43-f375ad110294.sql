CREATE OR REPLACE FUNCTION public.valider_specimen(_specimen_id uuid)
RETURNS TABLE(reference text, total_quantite integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spec record;
  v_ligne record;
  v_stock_dispo integer;
BEGIN
  RAISE LOG '[specimens] valider_specimen start user=% specimen=%', auth.uid(), _specimen_id;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour valider une remise de spécimens'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_spec FROM public.specimens WHERE specimen_id = _specimen_id FOR UPDATE;
  IF v_spec IS NULL THEN
    RAISE EXCEPTION 'Spécimen introuvable';
  END IF;
  IF v_spec.statut <> 'brouillon' THEN
    RAISE EXCEPTION 'Seules les remises en brouillon peuvent être validées (statut actuel: %)', v_spec.statut;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.specimen_lignes WHERE specimen_id = _specimen_id) THEN
    RAISE EXCEPTION 'Impossible de valider : la remise ne contient aucune ligne';
  END IF;

  FOR v_ligne IN
    SELECT sl.produit_id, sl.designation, SUM(sl.quantite)::integer AS qte
    FROM public.specimen_lignes sl
    WHERE sl.specimen_id = _specimen_id
    GROUP BY sl.produit_id, sl.designation
  LOOP
    SELECT COALESCE(stock, 0) INTO v_stock_dispo
      FROM public.produits WHERE produit_id = v_ligne.produit_id;
    IF COALESCE(v_stock_dispo, 0) < v_ligne.qte THEN
      RAISE EXCEPTION 'Stock insuffisant pour "%": disponible %, demandé %',
        v_ligne.designation, COALESCE(v_stock_dispo, 0), v_ligne.qte;
    END IF;
  END LOOP;

  FOR v_ligne IN
    SELECT produit_id, quantite FROM public.specimen_lignes WHERE specimen_id = _specimen_id
  LOOP
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif)
    VALUES (v_ligne.produit_id, 'sortie', v_ligne.quantite, 'Spécimen ' || v_spec.reference);
  END LOOP;

  UPDATE public.specimens SET statut = 'validee', updated_at = now()
    WHERE specimen_id = _specimen_id
    RETURNING * INTO v_spec;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'validate_specimen', 'specimens', _specimen_id::text);

  INSERT INTO public.notifications (titre, message, type_notification)
    VALUES ('Remise de spécimens validée',
            'Remise ' || v_spec.reference || ' validée : ' || v_spec.total_quantite || ' article(s) sortis du stock.',
            'info')
    ON CONFLICT DO NOTHING;

  RAISE LOG '[specimens] valider_specimen success specimen=% reference=% total=%',
    _specimen_id, v_spec.reference, v_spec.total_quantite;

  RETURN QUERY SELECT v_spec.reference, v_spec.total_quantite;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[specimens] valider_specimen error specimen=% sqlstate=% message=%', _specimen_id, SQLSTATE, SQLERRM;
  RAISE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.valider_specimen(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.valider_specimen(uuid) TO authenticated;