
-- Generic audit-capture trigger function
CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_action public.audit_action;
  v_old jsonb;
  v_new jsonb;
  v_changes jsonb;
  v_record_id text;
  v_record_ref text;
  v_user_id uuid;
  v_user_email text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_action := 'INSERT'; v_new := to_jsonb(NEW); v_old := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'UPDATE'; v_new := to_jsonb(NEW); v_old := to_jsonb(OLD);
    -- Skip no-op updates
    IF v_new = v_old THEN RETURN NEW; END IF;
    SELECT jsonb_object_agg(key, jsonb_build_object('old', v_old->key, 'new', v_new->key))
      INTO v_changes
      FROM jsonb_each(v_new)
     WHERE v_new->key IS DISTINCT FROM v_old->key;
  ELSE
    v_action := 'DELETE'; v_new := NULL; v_old := to_jsonb(OLD);
  END IF;

  v_record_id  := COALESCE(v_new->>'id', v_old->>'id');
  v_record_ref := COALESCE(
    v_new->>'reference', v_old->>'reference',
    v_new->>'numero',    v_old->>'numero',
    v_new->>'code',      v_old->>'code',
    v_new->>'nom',       v_old->>'nom'
  );

  BEGIN v_user_id := auth.uid(); EXCEPTION WHEN OTHERS THEN v_user_id := NULL; END;
  BEGIN v_user_email := (auth.jwt() ->> 'email'); EXCEPTION WHEN OTHERS THEN v_user_email := NULL; END;

  INSERT INTO public.audit_events(
    user_id, user_email, action, module, table_name,
    record_id, record_ref, old_values, new_values, changes, status
  ) VALUES (
    v_user_id, v_user_email, v_action, TG_TABLE_SCHEMA, TG_TABLE_NAME,
    v_record_id, v_record_ref, v_old, v_new, v_changes, 'success'
  );

  RETURN COALESCE(NEW, OLD);
EXCEPTION WHEN OTHERS THEN
  -- Never break a business transaction because of audit
  RETURN COALESCE(NEW, OLD);
END $$;

-- Attach trigger to each business table (idempotent)
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'clients','produits','commandes','commande_lignes',
    'factures','paiements','livraisons','livraisons_commande',
    'colis','colis_lignes','tournees','bons_livraison','bons_retour',
    'retours','retour_lignes','employes','user_roles',
    'rbac_user_roles','rbac_role_permissions','rbac_roles','rbac_permissions',
    'parametres','depots','fournisseurs','stock_mouvements',
    'stocks_depots','inventaires','inventaire_lignes',
    'bulletins_paie','fne_factures','proformas','proforma_lignes',
    'achats','achat_lignes','transferts','transfert_lignes',
    'transactions','ecritures_comptables','ecriture_lignes',
    'specimens','specimen_lignes','ordres_colisage',
    'preparateurs_colisage','colisage_responsables','vehicules',
    'livreurs','transporteurs','absences','conges','contrats','evaluations'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = t) THEN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%1$s ON public.%1$I', t);
      EXECUTE format(
        'CREATE TRIGGER trg_audit_%1$s
           AFTER INSERT OR UPDATE OR DELETE ON public.%1$I
           FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()', t);
    END IF;
  END LOOP;
END $$;
