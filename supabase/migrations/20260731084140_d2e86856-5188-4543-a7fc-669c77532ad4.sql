-- Lot 2 : bascule des lectures permissives vers rbac3

-- Helper: policies transactionnelles gardées par permission
DO $$
DECLARE
  r record;
  perm_map jsonb := jsonb_build_object(
    'audit_stock',            'stocks.lire',
    'bons_livraison',         'logistique.lire|commandes.lire',
    'colis',                  'logistique.lire',
    'colis_lignes',           'logistique.lire',
    'colis_statut_historique','logistique.lire',
    'commandes',              'commandes.lire|logistique.lire',
    'commande_lignes',        'commandes.lire|logistique.lire',
    'crm_interactions',       'clients.lire',
    'expeditions',            'logistique.lire',
    'historique_envois',      'logistique.lire',
    'livraisons',             'logistique.lire',
    'livraisons_commande',    'logistique.lire',
    'livsuivi_commandes',     'logistique.lire',
    'livsuivi_historique',    'logistique.lire',
    'missions',               'logistique.lire',
    'preparateurs_colisage',  'logistique.lire',
    'fne_factures',           'factures.lire',
    'incidents',              'stocks.lire',
    'incident_alerts',        'stocks.lire',
    'incident_lignes',        'stocks.lire',
    'inventaire_lignes',      'inventaires.lire',
    'produits',               'produits.lire|catalogue.lire',
    'proformas',              'devis.lire',
    'proforma_lignes',        'devis.lire',
    'retours',                'retours.lire',
    'retour_lignes',          'retours.lire',
    'specimens',              'ventes.lire|commandes.lire',
    'specimen_lignes',        'ventes.lire|commandes.lire',
    'transfert_lignes',       'stocks.lire'
  );
  k text;
  v text;
  parts text[];
  cond text;
BEGIN
  FOR k, v IN SELECT key, value #>> '{}' FROM jsonb_each(perm_map) LOOP
    parts := string_to_array(v, '|');
    SELECT string_agg(format('public.rbac3_can(%L)', p), ' OR ') INTO cond FROM unnest(parts) p;
    FOR r IN
      SELECT policyname FROM pg_policies
      WHERE schemaname='public' AND tablename=k AND cmd='SELECT'
        AND coalesce(qual,'true')='true'
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, k);
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (%s)',
        r.policyname, k, cond
      );
    END LOOP;
  END LOOP;
END $$;

-- Tables de référence : lecture réservée aux utilisateurs connectés
DO $$
DECLARE
  r record;
  t text;
  refs text[] := ARRAY[
    'categories_produits','document_templates','documents','gares','livreurs',
    'preparateurs','transporteurs','vehicules','services','parametres_entreprise',
    'approbation_seuils','workflows_definitions'
  ];
BEGIN
  FOREACH t IN ARRAY refs LOOP
    FOR r IN
      SELECT policyname FROM pg_policies
      WHERE schemaname='public' AND tablename=t AND cmd='SELECT'
        AND coalesce(qual,'true')='true'
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, t);
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL)',
        r.policyname, t
      );
    END LOOP;
  END LOOP;
END $$;

-- Catalogues rbac3 : lecture connectée uniquement (au lieu de public)
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT tablename, policyname FROM pg_policies
    WHERE schemaname='public' AND tablename IN
      ('rbac3_actions','rbac3_modules','rbac3_permissions','rbac3_role_permissions','rbac3_roles')
      AND cmd='SELECT' AND coalesce(qual,'true')='true'
  LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL)',
      r.policyname, r.tablename
    );
  END LOOP;
END $$;