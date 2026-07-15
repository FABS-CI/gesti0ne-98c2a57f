
CREATE OR REPLACE FUNCTION public.report_client_duplicates()
RETURNS TABLE(nom_normalise text, nb int, client_ids uuid[], noms text[])
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT LOWER(TRIM(nom)), COUNT(*)::int,
         array_agg(client_id ORDER BY created_at),
         array_agg(nom ORDER BY created_at)
  FROM public.clients
  WHERE nom IS NOT NULL AND TRIM(nom) <> ''
  GROUP BY 1 HAVING COUNT(*) > 1
  ORDER BY 2 DESC, 1;
$$;
REVOKE EXECUTE ON FUNCTION public.report_client_duplicates() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.report_client_duplicates() TO authenticated;

CREATE OR REPLACE FUNCTION public.report_bl_orphelins()
RETURNS TABLE(bl_id uuid, reference text, statut text, client_id uuid, montant numeric, cree_le timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT bl.bl_id, bl.reference, bl.statut::text, bl.client_id, bl.montant_total, bl.created_at
  FROM public.bons_livraison bl
  WHERE bl.commande_id IS NULL
  ORDER BY bl.created_at DESC;
$$;
REVOKE EXECUTE ON FUNCTION public.report_bl_orphelins() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.report_bl_orphelins() TO authenticated;

CREATE OR REPLACE FUNCTION public.report_stock_ecarts()
RETURNS TABLE(produit_id uuid, titre text, stock_actuel int, stock_calcule int, ecart int)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT p.produit_id, p.titre,
         COALESCE(p.stock,0)::int,
         COALESCE(SUM(m.quantite),0)::int,
         (COALESCE(p.stock,0) - COALESCE(SUM(m.quantite),0))::int
  FROM public.produits p
  LEFT JOIN public.stock_mouvements m ON m.produit_id = p.produit_id
  GROUP BY p.produit_id, p.titre, p.stock
  HAVING (COALESCE(p.stock,0) - COALESCE(SUM(m.quantite),0)) <> 0
  ORDER BY ABS(COALESCE(p.stock,0) - COALESCE(SUM(m.quantite),0)) DESC
  LIMIT 500;
$$;
REVOKE EXECUTE ON FUNCTION public.report_stock_ecarts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.report_stock_ecarts() TO authenticated;

CREATE OR REPLACE FUNCTION public.merge_clients(_keep_id uuid, _dup_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v jsonb := '{}'::jsonb; n int;
BEGIN
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN RAISE EXCEPTION 'Réservé au super_admin'; END IF;
  IF _keep_id IS NULL OR _dup_ids IS NULL OR array_length(_dup_ids,1) IS NULL THEN RAISE EXCEPTION 'Paramètres invalides'; END IF;
  IF _keep_id = ANY(_dup_ids) THEN RAISE EXCEPTION 'Le client conservé ne peut pas être dans la liste des doublons'; END IF;

  UPDATE public.commandes      SET client_id=_keep_id WHERE client_id = ANY(_dup_ids);
  GET DIAGNOSTICS n=ROW_COUNT; v := v || jsonb_build_object('commandes', n);
  UPDATE public.factures       SET client_id=_keep_id WHERE client_id = ANY(_dup_ids);
  GET DIAGNOSTICS n=ROW_COUNT; v := v || jsonb_build_object('factures', n);
  UPDATE public.bons_livraison SET client_id=_keep_id WHERE client_id = ANY(_dup_ids);
  GET DIAGNOSTICS n=ROW_COUNT; v := v || jsonb_build_object('bons_livraison', n);
  UPDATE public.proformas      SET client_id=_keep_id WHERE client_id = ANY(_dup_ids);
  GET DIAGNOSTICS n=ROW_COUNT; v := v || jsonb_build_object('proformas', n);
  UPDATE public.paiements      SET client_id=_keep_id WHERE client_id = ANY(_dup_ids);
  GET DIAGNOSTICS n=ROW_COUNT; v := v || jsonb_build_object('paiements', n);
  DELETE FROM public.clients WHERE client_id = ANY(_dup_ids);
  GET DIAGNOSTICS n=ROW_COUNT; v := v || jsonb_build_object('clients_supprimes', n);

  INSERT INTO public.audit_logs(action, table_name, record_id, new_values, user_id)
  VALUES ('merge_clients', 'clients', _keep_id, v || jsonb_build_object('dup_ids', to_jsonb(_dup_ids)), auth.uid());
  RETURN v;
END $$;
REVOKE EXECUTE ON FUNCTION public.merge_clients(uuid, uuid[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.merge_clients(uuid, uuid[]) TO authenticated;
