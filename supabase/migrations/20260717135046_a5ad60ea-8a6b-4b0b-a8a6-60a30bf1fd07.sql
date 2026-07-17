
-- Nouvelle règle métier : CA = somme des paiements validés
-- rapport_kpi, crm_dashboard, dashboard_overview_full : `ca` bascule sur paiements
-- Ajout de : montant_facture, reste_a_encaisser, taux_encaissement

CREATE OR REPLACE FUNCTION public.rapport_kpi(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ca numeric;
  v_facture numeric;
BEGIN
  PERFORM public.assert_permission('rapports.voir_ca');

  SELECT COALESCE(SUM(montant),0) INTO v_ca
    FROM public.paiements WHERE statut = 'valide';

  SELECT COALESCE(SUM(montant_total),0) INTO v_facture
    FROM public.factures WHERE COALESCE(statut,'') <> 'annulee';

  RETURN jsonb_build_object(
    'qte_vendue', 0, 'qte_facturee', 0,
    'nb_factures', COALESCE((SELECT count(*) FROM public.factures WHERE COALESCE(statut,'') <> 'annulee'), 0),
    'nb_clients', COALESCE((SELECT count(*) FROM public.clients), 0),
    -- CA = paiements encaissés (nouvelle définition)
    'ca', v_ca,
    -- Indicateurs distincts
    'montant_facture', v_facture,
    'montant_encaisse', v_ca,
    'reste_a_encaisser', GREATEST(0, v_facture - v_ca),
    'taux_encaissement', CASE WHEN v_facture > 0 THEN ROUND((v_ca / v_facture) * 100, 2) ELSE 0 END,
    'nb_commandes', COALESCE((SELECT count(*) FROM public.commandes), 0),
    'prix_moyen', 0, 'panier_moyen', 0,
    'top_produit', NULL, 'rentable_produit', NULL, 'flop_produit', NULL
  );
END; $function$;

CREATE OR REPLACE FUNCTION public.crm_dashboard(_from date DEFAULT NULL::date, _to date DEFAULT NULL::date)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ca numeric;
  v_facture numeric;
BEGIN
  PERFORM public.assert_permission('dashboard_direction.voir');

  SELECT COALESCE(SUM(montant),0) INTO v_ca
    FROM public.paiements
    WHERE statut = 'valide'
      AND (_from IS NULL OR date_paiement >= _from)
      AND (_to IS NULL OR date_paiement <= _to);

  SELECT COALESCE(SUM(montant_total),0) INTO v_facture
    FROM public.factures
    WHERE COALESCE(statut,'') <> 'annulee'
      AND (_from IS NULL OR date_facture >= _from)
      AND (_to IS NULL OR date_facture <= _to);

  RETURN jsonb_build_object(
    'ca_total', v_ca,                       -- CA = paiements encaissés
    'montant_facture', v_facture,
    'montant_encaisse', v_ca,
    'reste_a_encaisser', GREATEST(0, v_facture - v_ca),
    'taux_encaissement', CASE WHEN v_facture > 0 THEN ROUND((v_ca / v_facture) * 100, 2) ELSE 0 END,
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
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_since date := current_date - _periode_jours;
  v_ca numeric;
  v_facture numeric;
BEGIN
  PERFORM public.assert_permission('dashboard_direction.voir');

  -- CA (nouveau) = paiements validés sur la période
  SELECT COALESCE(SUM(montant),0) INTO v_ca
    FROM public.paiements
    WHERE statut = 'valide' AND date_paiement >= v_since;

  SELECT COALESCE(SUM(montant_total),0) INTO v_facture
    FROM public.factures
    WHERE exercice_id = _exercice_id
      AND COALESCE(statut,'') <> 'annulee'
      AND date_facture >= v_since;

  RETURN jsonb_build_object(
    'nbCommandes', COALESCE((SELECT count(*) FROM public.commandes
        WHERE exercice_id = _exercice_id AND date_commande >= v_since), 0),
    -- CA = paiements encaissés (nouvelle définition)
    'caTotal', v_ca,
    'montantFacture', v_facture,
    'montantEncaisse', v_ca,
    'resteAEncaisser', GREATEST(0, v_facture - v_ca),
    'tauxEncaissement', CASE WHEN v_facture > 0 THEN ROUND((v_ca / v_facture) * 100, 2) ELSE 0 END,
    'parStatut', COALESCE((SELECT jsonb_agg(jsonb_build_object('statut', statut, 'count', c)) FROM (
      SELECT statut, count(*) c FROM public.commandes WHERE exercice_id = _exercice_id GROUP BY statut
    ) x), '[]'::jsonb),
    -- caMensuel bascule aussi sur paiements encaissés
    'caMensuel', COALESCE((SELECT jsonb_agg(jsonb_build_object('y', y, 'm', m, 'ca', ca, 'nb', nb)) FROM (
      SELECT extract(year FROM date_paiement)::int y, extract(month FROM date_paiement)::int m,
             sum(montant) ca, count(*) nb
      FROM public.paiements
      WHERE statut = 'valide'
        AND date_paiement >= (current_date - interval '6 months')
      GROUP BY 1,2 ORDER BY 1,2
    ) x), '[]'::jsonb),
    'recettes', v_ca,
    'depenses', COALESCE((SELECT sum(montant) FROM public.achats WHERE statut = 'paye' AND date_achat >= v_since), 0),
    'solde', v_ca - COALESCE((SELECT sum(montant) FROM public.achats WHERE statut = 'paye' AND date_achat >= v_since), 0),
    'stockBas', '[]'::jsonb, 'nbStockBas', 0,
    'nbRetards', COALESCE((SELECT count(*) FROM public.factures WHERE statut IN ('impayee','partielle') AND date_echeance < current_date), 0),
    'montantRetard', COALESCE((SELECT sum(montant_total - COALESCE(montant_paye,0)) FROM public.factures WHERE statut IN ('impayee','partielle') AND date_echeance < current_date), 0)
  );
END; $function$;
