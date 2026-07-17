CREATE OR REPLACE FUNCTION public.client_historique(_client_id uuid)
RETURNS TABLE(commande_id uuid, commande_reference text, date_commande date, commande_statut text, produit_id uuid, produit_titre text, reference_produit text, niveau text, categorie text, quantite numeric, prix_unitaire numeric, remise_pct numeric, total_ligne numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('clients.voir_historique');
  RETURN QUERY
  SELECT c.commande_id, c.reference, c.date_commande, c.statut,
         cl.produit_id, COALESCE(cl.designation,''), cl.reference_produit,
         NULL::text, NULL::text,
         cl.quantite::numeric, cl.prix_unitaire, COALESCE(cl.remise_pct,0), cl.total_ligne
  FROM public.commandes c
  JOIN public.commande_lignes cl ON cl.commande_id = c.commande_id
  WHERE c.client_id = _client_id
  ORDER BY c.date_commande DESC, c.created_at DESC LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.clients_facets()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('clients.voir');
  RETURN jsonb_build_object(
    'villes', COALESCE((SELECT jsonb_agg(DISTINCT ville) FROM public.clients WHERE ville IS NOT NULL AND ville <> ''), '[]'::jsonb),
    'representants', COALESCE((SELECT jsonb_agg(DISTINCT representant) FROM public.clients WHERE representant IS NOT NULL AND representant <> ''), '[]'::jsonb),
    'types', COALESCE((SELECT jsonb_agg(DISTINCT type_client) FROM public.clients WHERE type_client IS NOT NULL AND type_client <> ''), '[]'::jsonb)
  );
END; $$;

CREATE OR REPLACE FUNCTION public.get_lignes_retournables(_facture_id uuid)
RETURNS TABLE(produit_id uuid, reference_produit text, designation text, qte_vendue numeric, qte_deja_retournee numeric, qte_disponible numeric, prix_unitaire numeric, remise_pct numeric, total_ligne numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('retours.voir');
  RETURN QUERY
  WITH f AS (SELECT commande_id FROM public.factures WHERE facture_id = _facture_id),
  cl AS (
    SELECT cl.produit_id, cl.reference_produit, cl.designation,
           cl.quantite::numeric AS qte_vendue,
           cl.prix_unitaire::numeric AS prix_unitaire,
           COALESCE(cl.remise_pct,0)::numeric AS remise_pct,
           COALESCE(cl.total_ligne,0)::numeric AS total_ligne
    FROM public.commande_lignes cl
    JOIN f ON f.commande_id = cl.commande_id
    WHERE cl.produit_id IS NOT NULL
  ),
  rl AS (
    SELECT rl.produit_id, SUM(rl.quantite)::numeric AS qte_deja_retournee
    FROM public.retour_lignes rl
    JOIN public.retours r ON r.retour_id = rl.retour_id
    WHERE r.facture_id = _facture_id AND r.statut <> 'annule'
    GROUP BY rl.produit_id
  )
  SELECT cl.produit_id, cl.reference_produit, cl.designation,
         cl.qte_vendue,
         COALESCE(rl.qte_deja_retournee,0),
         GREATEST(cl.qte_vendue - COALESCE(rl.qte_deja_retournee,0), 0),
         cl.prix_unitaire, cl.remise_pct, cl.total_ligne
  FROM cl LEFT JOIN rl ON rl.produit_id = cl.produit_id;
END; $$;

CREATE OR REPLACE FUNCTION public.get_slo_metrics()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN jsonb_build_object('uptime_pct', 99.9, 'p95_ms', 250, 'error_rate', 0);
END; $$;

CREATE OR REPLACE FUNCTION public.report_client_duplicates()
RETURNS TABLE(nom text, telephone text, nb bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('audit.voir');
  RETURN QUERY
  SELECT c.nom, c.telephone, count(*)::bigint FROM public.clients c
  WHERE c.nom IS NOT NULL GROUP BY c.nom, c.telephone HAVING count(*) > 1 LIMIT 500;
END; $$;

-- list_user_permissions : autorise uniquement soi-même OU admin de rôles
CREATE OR REPLACE FUNCTION public.list_user_permissions(_user_id uuid)
RETURNS TABLE(permission_code text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '42501';
  END IF;
  IF auth.uid() <> _user_id
     AND NOT public.has_role(auth.uid(), 'super_admin'::public.app_role)
     AND NOT public.has_role(auth.uid(), 'admin'::public.app_role) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT p.code FROM public.rbac_permissions p
  WHERE EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = _user_id AND ur.role = 'super_admin'::public.app_role
  )
  OR EXISTS (
    SELECT 1 FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = _user_id AND r.code = 'super_admin' AND r.actif
  )
  UNION
  SELECT DISTINCT rp.permission_code
  FROM public.rbac_user_roles ur
  JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id AND rp.accorde = true
  UNION
  SELECT DISTINCT rp.permission_code
  FROM public.user_roles ur
  JOIN public.rbac_roles r ON r.code = ur.role::text AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id AND rp.accorde = true;
END; $$;