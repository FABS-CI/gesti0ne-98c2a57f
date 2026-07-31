DO $$
DECLARE
  m jsonb := '{
    "absences":"rh","bulletin_lignes":"rh","bulletins_paie":"rh","conges":"rh","contrats":"rh",
    "declarations_paie":"rh","departements":"rh","employe_documents":"rh","employes":"rh",
    "evaluations":"rh","fonctions":"rh","parametres_paie":"rh","rubriques_paie":"rh",
    "services":"rh","missions":"rh",
    "ecriture_lignes":"comptabilite","ecritures_comptables":"comptabilite","exercices_comptables":"comptabilite",
    "journaux_comptables":"comptabilite","plan_comptable":"comptabilite","transactions":"comptabilite",
    "soldes_ouverture_clients":"comptabilite","soldes_ouverture_fournisseurs":"comptabilite",
    "exercice_cloture_journal":"comptabilite",
    "fne_declarations":"factures","fne_settings":"factures","fne_factures":"factures",
    "achats":"achats","achat_lignes":"achats","fournisseurs":"fournisseurs",
    "clients":"clients","crm_interactions":"clients",
    "produits":"produits","categories_produits":"produits",
    "stock_mouvements":"stocks","stocks_depots":"stocks","alertes_stock":"stocks",
    "inventaires":"inventaires","inventaire_lignes":"inventaires",
    "incidents":"stocks","incident_lignes":"stocks","incident_alerts":"stocks",
    "transferts":"stocks","transfert_lignes":"stocks",
    "approvisionnements":"stocks","approvisionnement_lignes":"stocks",
    "depots":"depots",
    "gares":"logistique","transporteurs":"logistique","tournees":"logistique","expeditions":"logistique",
    "livraisons":"logistique","livraisons_commande":"logistique","livreurs":"logistique","vehicules":"logistique",
    "colisage_responsables":"logistique","preparateurs":"logistique","preparateurs_colisage":"logistique",
    "couts_logistiques":"logistique",
    "proformas":"ventes","proforma_lignes":"ventes","specimens":"ventes","specimen_lignes":"ventes",
    "retours":"retours","retour_lignes":"retours",
    "backups":"administration","backup_schedules":"administration","parametres_entreprise":"administration",
    "parametres_systeme":"administration","document_templates":"administration","approbation_seuils":"administration",
    "workflows_definitions":"administration","user_depots":"administration","security_alerts":"administration",
    "rbac2_domains":"administration","rbac2_modules":"administration","rbac2_perm_deps":"administration",
    "rbac2_permissions":"administration","rbac2_resources":"administration","rbac2_role_parents":"administration",
    "rbac2_role_perms":"administration","rbac2_roles":"administration","rbac2_user_roles":"administration",
    "rbac_permissions":"administration","rbac_role_permissions":"administration","rbac_roles":"administration",
    "rbac_user_roles":"administration"
  }'::jsonb;
  legacy text[] := ARRAY['is_hr(','is_finance(','is_admin(','is_stock(','is_sales(','has_role_compat(','can_write_module(','has_permission(','depot_in_scope('];
  r record;
  tbl text;
  modl text;
  pred text;
  has_depot boolean;
  matched boolean;
  l text;
BEGIN
  FOR r IN
    SELECT p.tablename, p.policyname, p.cmd, p.qual, p.with_check
    FROM pg_policies p
    WHERE p.schemaname='public'
      AND p.cmd IN ('INSERT','UPDATE','DELETE','ALL')
      AND m ? p.tablename
  LOOP
    tbl := r.tablename;
    modl := m->>tbl;
    matched := false;
    FOREACH l IN ARRAY legacy LOOP
      IF position(l in coalesce(r.qual,'') || ' ' || coalesce(r.with_check,'')) > 0 THEN
        matched := true;
      END IF;
    END LOOP;
    CONTINUE WHEN NOT matched;

    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema='public' AND c.table_name=tbl AND c.column_name='depot_id'
    ) INTO has_depot;

    pred := format('rbac3_can(%L)', modl || '.modifier');
    IF has_depot THEN
      pred := pred || ' AND (depot_id IS NULL OR rbac3_scope_depot(depot_id))';
    END IF;

    EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, tbl);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (%s) WITH CHECK (%s)',
      left('rbac3_write_' || tbl || '_' || md5(r.policyname), 60), tbl, pred, pred
    );
  END LOOP;
END $$;