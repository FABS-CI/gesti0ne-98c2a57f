
-- Lot 6 : rapports + dashboards + factures_list_paginated

CREATE OR REPLACE FUNCTION public.rapport_kpi(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN jsonb_build_object(
    'qte_vendue', 0, 'qte_facturee', 0,
    'nb_factures', COALESCE((SELECT count(*) FROM public.factures), 0),
    'nb_clients', COALESCE((SELECT count(*) FROM public.clients), 0),
    'ca', COALESCE((SELECT sum(montant_total) FROM public.commandes), 0),
    'nb_commandes', COALESCE((SELECT count(*) FROM public.commandes), 0),
    'prix_moyen', 0, 'panier_moyen', 0,
    'top_produit', NULL, 'rentable_produit', NULL, 'flop_produit', NULL
  );
END; $function$;

CREATE OR REPLACE FUNCTION public.rapport_agregat(_filtres jsonb DEFAULT '{}'::jsonb, _dimension text DEFAULT 'ville')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN '[]'::jsonb;
END; $function$;

CREATE OR REPLACE FUNCTION public.rapport_evolution(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN '[]'::jsonb;
END; $function$;

CREATE OR REPLACE FUNCTION public.rapport_top_produits(_filtres jsonb DEFAULT '{}'::jsonb, _limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN '[]'::jsonb;
END; $function$;

CREATE OR REPLACE FUNCTION public.rapport_flop_produits(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN jsonb_build_object('jamais_vendus', '[]'::jsonb, 'peu_vendus', '[]'::jsonb);
END; $function$;

CREATE OR REPLACE FUNCTION public.rapport_produits(_filtres jsonb DEFAULT '{}'::jsonb, _tri text DEFAULT 'ca', _sens text DEFAULT 'desc', _limit integer DEFAULT 50, _offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN jsonb_build_object('total', 0, 'items', '[]'::jsonb);
END; $function$;

CREATE OR REPLACE FUNCTION public.rapport_clients_produit(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN '[]'::jsonb;
END; $function$;

CREATE OR REPLACE FUNCTION public.crm_dashboard(_from date DEFAULT NULL, _to date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('dashboard_direction.voir');
  RETURN jsonb_build_object(
    'ca_total', COALESCE((SELECT sum(montant_total) FROM public.commandes WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'nb_commandes', COALESCE((SELECT count(*) FROM public.commandes WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'nb_clients', COALESCE((SELECT count(DISTINCT client_id) FROM public.commandes WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'par_niveau', '[]'::jsonb, 'par_categorie', '[]'::jsonb, 'par_ville', '[]'::jsonb,
    'par_type_client', '[]'::jsonb, 'top_produits', '[]'::jsonb, 'flop_produits', '[]'::jsonb,
    'ca_mensuel', '[]'::jsonb, 'top_clients', '[]'::jsonb, 'top_representants', '[]'::jsonb
  );
END; $function$;

CREATE OR REPLACE FUNCTION public.dashboard_client_stats()
RETURNS TABLE(total bigint, actifs bigint, solde_total numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('dashboard_direction.voir');
  RETURN QUERY SELECT
    (SELECT count(*) FROM public.clients),
    (SELECT count(*) FROM public.clients WHERE COALESCE(actif,true) AND COALESCE(statut,'actif') = 'actif'),
    COALESCE((SELECT sum(solde) FROM public.clients), 0);
END; $function$;

CREATE OR REPLACE FUNCTION public.dashboard_overview_full(_exercice_id uuid, _periode_jours integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_since date := current_date - _periode_jours;
BEGIN
  PERFORM public.assert_permission('dashboard_direction.voir');
  RETURN jsonb_build_object(
    'nbCommandes', COALESCE((SELECT count(*) FROM public.commandes WHERE exercice_id = _exercice_id AND date_commande >= v_since), 0),
    'caTotal', COALESCE((SELECT sum(montant_total) FROM public.commandes WHERE exercice_id = _exercice_id AND date_commande >= v_since), 0),
    'parStatut', COALESCE((SELECT jsonb_agg(jsonb_build_object('statut', statut, 'count', c)) FROM (
      SELECT statut, count(*) c FROM public.commandes WHERE exercice_id = _exercice_id GROUP BY statut
    ) x), '[]'::jsonb),
    'caMensuel', COALESCE((SELECT jsonb_agg(jsonb_build_object('y', y, 'm', m, 'ca', ca, 'nb', nb)) FROM (
      SELECT extract(year FROM date_commande)::int y, extract(month FROM date_commande)::int m,
             sum(montant_total) ca, count(*) nb
      FROM public.commandes WHERE exercice_id = _exercice_id AND date_commande >= (current_date - interval '6 months')
      GROUP BY 1,2 ORDER BY 1,2
    ) x), '[]'::jsonb),
    'recettes', COALESCE((SELECT sum(montant) FROM public.paiements WHERE statut = 'valide' AND date_paiement >= v_since), 0),
    'depenses', COALESCE((SELECT sum(montant) FROM public.achats WHERE statut = 'paye' AND date_achat >= v_since), 0),
    'solde', COALESCE((SELECT sum(montant) FROM public.paiements WHERE statut = 'valide' AND date_paiement >= v_since), 0)
             - COALESCE((SELECT sum(montant) FROM public.achats WHERE statut = 'paye' AND date_achat >= v_since), 0),
    'stockBas', '[]'::jsonb, 'nbStockBas', 0,
    'nbRetards', COALESCE((SELECT count(*) FROM public.factures WHERE statut IN ('impayee','partielle') AND date_echeance < current_date), 0),
    'montantRetard', COALESCE((SELECT sum(montant_total - COALESCE(montant_paye,0)) FROM public.factures WHERE statut IN ('impayee','partielle') AND date_echeance < current_date), 0)
  );
END; $function$;

CREATE OR REPLACE FUNCTION public.factures_list_paginated(_q text DEFAULT NULL, _statut text DEFAULT NULL, _date_du date DEFAULT NULL, _date_au date DEFAULT NULL, _exercice_id uuid DEFAULT NULL, _page integer DEFAULT 1, _page_size integer DEFAULT 20)
RETURNS TABLE(items jsonb, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_offset int := (GREATEST(_page,1)-1) * GREATEST(_page_size,1); v_total bigint;
BEGIN
  PERFORM public.assert_permission('factures.voir');
  SELECT count(*) INTO v_total FROM public.factures f
   WHERE (_exercice_id IS NULL OR f.exercice_id = _exercice_id)
     AND (_statut IS NULL OR f.statut = _statut)
     AND (_date_du IS NULL OR f.date_facture >= _date_du)
     AND (_date_au IS NULL OR f.date_facture <= _date_au)
     AND (_q IS NULL OR f.reference ILIKE '%'||_q||'%' OR COALESCE(f.client_nom,'') ILIKE '%'||_q||'%');

  RETURN QUERY
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC), '[]'::jsonb), v_total
  FROM (
    SELECT * FROM public.factures f
     WHERE (_exercice_id IS NULL OR f.exercice_id = _exercice_id)
       AND (_statut IS NULL OR f.statut = _statut)
       AND (_date_du IS NULL OR f.date_facture >= _date_du)
       AND (_date_au IS NULL OR f.date_facture <= _date_au)
       AND (_q IS NULL OR f.reference ILIKE '%'||_q||'%' OR COALESCE(f.client_nom,'') ILIKE '%'||_q||'%')
     ORDER BY f.created_at DESC
     LIMIT GREATEST(_page_size,1) OFFSET v_offset
  ) x;
END; $function$;
