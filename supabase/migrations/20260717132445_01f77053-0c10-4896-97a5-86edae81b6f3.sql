
CREATE OR REPLACE FUNCTION public.rapport_kpi(_filtres jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');
  RETURN jsonb_build_object(
    'qte_vendue', 0, 'qte_facturee', 0,
    'nb_factures', COALESCE((SELECT count(*) FROM public.factures WHERE COALESCE(statut,'') <> 'annulee'), 0),
    'nb_clients', COALESCE((SELECT count(*) FROM public.clients), 0),
    'ca', COALESCE((SELECT sum(montant_total) FROM public.factures WHERE COALESCE(statut,'') <> 'annulee'), 0),
    'nb_commandes', COALESCE((SELECT count(*) FROM public.commandes), 0),
    'prix_moyen', 0, 'panier_moyen', 0,
    'top_produit', NULL, 'rentable_produit', NULL, 'flop_produit', NULL
  );
END; $function$;

CREATE OR REPLACE FUNCTION public.crm_dashboard(_from date DEFAULT NULL::date, _to date DEFAULT NULL::date)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.assert_permission('dashboard_direction.voir');
  RETURN jsonb_build_object(
    'ca_total', COALESCE((SELECT sum(montant_total) FROM public.factures
       WHERE COALESCE(statut,'') <> 'annulee'
         AND (_from IS NULL OR date_facture >= _from)
         AND (_to IS NULL OR date_facture <= _to)), 0),
    'nb_commandes', COALESCE((SELECT count(*) FROM public.commandes
       WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'nb_clients', COALESCE((SELECT count(DISTINCT client_id) FROM public.commandes
       WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'par_niveau', '[]'::jsonb, 'par_categorie', '[]'::jsonb, 'par_ville', '[]'::jsonb,
    'par_type_client', '[]'::jsonb, 'top_produits', '[]'::jsonb, 'flop_produits', '[]'::jsonb,
    'ca_mensuel', '[]'::jsonb, 'top_clients', '[]'::jsonb, 'top_representants', '[]'::jsonb
  );
END; $function$;

CREATE OR REPLACE FUNCTION public.dashboard_overview_full(_exercice_id uuid, _periode_jours integer DEFAULT 30)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_since date := current_date - _periode_jours;
BEGIN
  PERFORM public.assert_permission('dashboard_direction.voir');
  RETURN jsonb_build_object(
    'nbCommandes', COALESCE((SELECT count(*) FROM public.commandes WHERE exercice_id = _exercice_id AND date_commande >= v_since), 0),
    'caTotal', COALESCE((SELECT sum(montant_total) FROM public.factures
        WHERE exercice_id = _exercice_id AND COALESCE(statut,'') <> 'annulee' AND date_facture >= v_since), 0),
    'parStatut', COALESCE((SELECT jsonb_agg(jsonb_build_object('statut', statut, 'count', c)) FROM (
      SELECT statut, count(*) c FROM public.commandes WHERE exercice_id = _exercice_id GROUP BY statut
    ) x), '[]'::jsonb),
    'caMensuel', COALESCE((SELECT jsonb_agg(jsonb_build_object('y', y, 'm', m, 'ca', ca, 'nb', nb)) FROM (
      SELECT extract(year FROM date_facture)::int y, extract(month FROM date_facture)::int m,
             sum(montant_total) ca, count(*) nb
      FROM public.factures
      WHERE exercice_id = _exercice_id AND COALESCE(statut,'') <> 'annulee'
        AND date_facture >= (current_date - interval '6 months')
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
