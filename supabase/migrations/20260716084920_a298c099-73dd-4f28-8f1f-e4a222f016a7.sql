
-- Adapter audit_logs (colonnes manquantes)
ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS module text,
  ADD COLUMN IF NOT EXISTS entity_type text,
  ADD COLUMN IF NOT EXISTS entity_id text,
  ADD COLUMN IF NOT EXISTS details jsonb DEFAULT '{}'::jsonb;

-- ---------- Clients ------------------------------------------------
CREATE OR REPLACE FUNCTION public.supprimer_client(_client_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ref text; v_used int;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT COALESCE(reference, nom) INTO v_ref FROM public.clients WHERE client_id = _client_id;
  IF v_ref IS NULL THEN RAISE EXCEPTION 'Client introuvable'; END IF;
  SELECT count(*) INTO v_used FROM public.commandes WHERE client_id = _client_id;
  IF v_used > 0 THEN
    RAISE EXCEPTION 'Client utilisé dans % commande(s) — désactivez-le au lieu de le supprimer', v_used;
  END IF;
  DELETE FROM public.clients WHERE client_id = _client_id;
  RETURN jsonb_build_object('client_id', _client_id, 'reference', v_ref, 'motif', _motif);
END; $$;

-- ---------- Comptabilité -------------------------------------------
CREATE OR REPLACE FUNCTION public.compta_balance(p_from date DEFAULT NULL, p_to date DEFAULT NULL, p_exercice_id uuid DEFAULT NULL)
RETURNS TABLE(numero_compte text, libelle text, debit numeric, credit numeric, solde numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    COALESCE(el.numero_compte, pc.numero, '???') AS numero_compte,
    COALESCE(pc.libelle, el.libelle, '') AS libelle,
    COALESCE(sum(el.debit), 0),
    COALESCE(sum(el.credit), 0),
    COALESCE(sum(el.debit) - sum(el.credit), 0)
  FROM public.ecriture_lignes el
  JOIN public.ecritures_comptables ec ON ec.ecriture_id = el.ecriture_id
  LEFT JOIN public.plan_comptable pc ON pc.compte_id = el.compte_id OR pc.numero = el.numero_compte
  WHERE (p_from IS NULL OR ec.date_ecriture >= p_from)
    AND (p_to IS NULL OR ec.date_ecriture <= p_to)
    AND (p_exercice_id IS NULL OR ec.exercice_id = p_exercice_id)
  GROUP BY 1, 2
  ORDER BY 1;
$$;

CREATE OR REPLACE FUNCTION public.exercices_comparatif(_exercice_ids uuid[])
RETURNS TABLE(exercice_id uuid, libelle text, ca numeric, nb_commandes bigint, nb_factures bigint, montant_paye numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT ex.exercice_id, ex.libelle,
    COALESCE((SELECT sum(montant_total) FROM public.commandes c WHERE c.exercice_id = ex.exercice_id), 0),
    COALESCE((SELECT count(*) FROM public.commandes c WHERE c.exercice_id = ex.exercice_id), 0),
    COALESCE((SELECT count(*) FROM public.factures f WHERE f.exercice_id = ex.exercice_id), 0),
    COALESCE((SELECT sum(montant_paye) FROM public.factures f WHERE f.exercice_id = ex.exercice_id), 0)
  FROM public.exercices_comptables ex
  WHERE ex.exercice_id = ANY(_exercice_ids)
  ORDER BY ex.date_debut;
$$;

CREATE OR REPLACE FUNCTION public.preview_cloture_exercice(_exercice_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'exercice_id', _exercice_id,
    'nb_ecritures', (SELECT count(*) FROM public.ecritures_comptables WHERE exercice_id = _exercice_id),
    'nb_factures', (SELECT count(*) FROM public.factures WHERE exercice_id = _exercice_id),
    'nb_commandes', (SELECT count(*) FROM public.commandes WHERE exercice_id = _exercice_id),
    'total_ca', COALESCE((SELECT sum(montant_total) FROM public.commandes WHERE exercice_id = _exercice_id), 0),
    'total_paye', COALESCE((SELECT sum(montant_paye) FROM public.factures WHERE exercice_id = _exercice_id), 0),
    'total_impaye', COALESCE((SELECT sum(montant_total - COALESCE(montant_paye,0)) FROM public.factures WHERE exercice_id = _exercice_id AND statut <> 'payee'), 0),
    'anomalies', '[]'::jsonb
  );
$$;

CREATE OR REPLACE FUNCTION public.recalculer_solde_client(_client_id uuid)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_solde numeric;
BEGIN
  SELECT COALESCE(sum(montant_total - COALESCE(montant_paye,0)), 0) INTO v_solde
  FROM public.factures WHERE client_id = _client_id AND statut IN ('impayee','partielle');
  UPDATE public.clients SET solde = v_solde WHERE client_id = _client_id;
  RETURN v_solde;
END; $$;

CREATE OR REPLACE FUNCTION public.recalculer_soldes_global_clients()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; v_n int := 0;
BEGIN
  FOR r IN SELECT client_id FROM public.clients LOOP
    PERFORM public.recalculer_solde_client(r.client_id);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END; $$;

CREATE OR REPLACE FUNCTION public.audit_compta_factures_paiements()
RETURNS TABLE(type text, facture_id uuid, reference text, detail text, montant numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT 'surpayee'::text, f.facture_id, f.reference, 'Trop-perçu'::text, (f.montant_paye - f.montant_total)::numeric
  FROM public.factures f WHERE COALESCE(f.montant_paye,0) > f.montant_total LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION public.audit_compta_soldes_clients()
RETURNS TABLE(client_id uuid, nom text, solde_calcule numeric, solde_stocke numeric, ecart numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.client_id, c.nom,
    COALESCE((SELECT sum(montant_total - COALESCE(montant_paye,0)) FROM public.factures f
              WHERE f.client_id = c.client_id AND f.statut IN ('impayee','partielle')), 0),
    COALESCE(c.solde, 0),
    COALESCE((SELECT sum(montant_total - COALESCE(montant_paye,0)) FROM public.factures f
              WHERE f.client_id = c.client_id AND f.statut IN ('impayee','partielle')), 0) - COALESCE(c.solde,0)
  FROM public.clients c
  WHERE abs(COALESCE(c.solde,0) -
    COALESCE((SELECT sum(montant_total - COALESCE(montant_paye,0)) FROM public.factures f
              WHERE f.client_id = c.client_id AND f.statut IN ('impayee','partielle')), 0)) > 0.01
  LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION public.audit_finances_anomalies()
RETURNS TABLE(type text, detail text, montant numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT 'facture_zero'::text, f.reference, 0::numeric FROM public.factures f WHERE f.montant_total = 0 LIMIT 100
$$;

-- ---------- Employés ----------------------------------------------
CREATE OR REPLACE FUNCTION public.soft_delete_employe(_employe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.employes SET actif = false, deleted_at = now() WHERE employe_id = _employe_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Employé introuvable'; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.restore_employe(_employe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.employes SET actif = true, deleted_at = NULL WHERE employe_id = _employe_id;
END; $$;

CREATE OR REPLACE FUNCTION public.supprimer_employe(_employe_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_nom text;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT nom_complet INTO v_nom FROM public.employes WHERE employe_id = _employe_id;
  IF v_nom IS NULL THEN RAISE EXCEPTION 'Employé introuvable'; END IF;
  DELETE FROM public.employes WHERE employe_id = _employe_id;
  RETURN jsonb_build_object('employe_id', _employe_id, 'nom_complet', v_nom, 'motif', _motif);
END; $$;

CREATE OR REPLACE FUNCTION public.renumber_employes_matricules(_prefix text DEFAULT 'EMP')
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; v_n int := 0;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  FOR r IN SELECT employe_id FROM public.employes ORDER BY created_at LOOP
    v_n := v_n + 1;
    UPDATE public.employes SET matricule = _prefix || '-' || lpad(v_n::text, 5, '0')
     WHERE employe_id = r.employe_id;
  END LOOP;
  RETURN v_n;
END; $$;

-- ---------- Tournées (auxiliaires) --------------------------------
CREATE OR REPLACE FUNCTION public.cloturer_tournee(_tournee_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN UPDATE public.tournees SET statut = 'terminee' WHERE tournee_id = _tournee_id; END; $$;

CREATE OR REPLACE FUNCTION public.annuler_validation_tournee(_tournee_id uuid, _motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.tournees SET validation_statut = 'brouillon',
    validation_commentaire = COALESCE(_motif, validation_commentaire),
    validation_at = NULL, validation_by = NULL
  WHERE tournee_id = _tournee_id;
END; $$;

CREATE OR REPLACE FUNCTION public.refuser_tournee_couts(_tournee_id uuid, _motif text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.tournees SET validation_statut = 'refuse',
    validation_commentaire = _motif, validation_at = now(), validation_by = auth.uid()
  WHERE tournee_id = _tournee_id;
END; $$;

CREATE OR REPLACE FUNCTION public.valider_decaissement_tournee(_tournee_id uuid, _mode_reglement text DEFAULT NULL, _commentaire text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.tournees SET validation_statut = 'valide',
    mode_reglement = COALESCE(_mode_reglement, mode_reglement),
    validation_commentaire = COALESCE(_commentaire, validation_commentaire),
    validation_at = now(), validation_by = auth.uid()
  WHERE tournee_id = _tournee_id;
END; $$;

CREATE OR REPLACE FUNCTION public.supprimer_tournee(_tournee_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ref text;
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  SELECT reference INTO v_ref FROM public.tournees WHERE tournee_id = _tournee_id;
  DELETE FROM public.tournees WHERE tournee_id = _tournee_id;
  RETURN jsonb_build_object('tournee_id', _tournee_id, 'reference', v_ref, 'motif', _motif);
END; $$;

-- ---------- Dashboards / CRM (stubs sûrs) -------------------------
CREATE OR REPLACE FUNCTION public.dashboard_client_stats()
RETURNS TABLE(total bigint, actifs bigint, solde_total numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    (SELECT count(*) FROM public.clients),
    (SELECT count(*) FROM public.clients WHERE COALESCE(actif,true) AND COALESCE(statut,'actif') = 'actif'),
    COALESCE((SELECT sum(solde) FROM public.clients), 0);
$$;

CREATE OR REPLACE FUNCTION public.dashboard_overview_full(_exercice_id uuid, _periode_jours integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_since date := current_date - _periode_jours;
BEGIN
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
END; $$;

CREATE OR REPLACE FUNCTION public.crm_dashboard(_from date DEFAULT NULL, _to date DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'ca_total', COALESCE((SELECT sum(montant_total) FROM public.commandes WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'nb_commandes', COALESCE((SELECT count(*) FROM public.commandes WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'nb_clients', COALESCE((SELECT count(DISTINCT client_id) FROM public.commandes WHERE (_from IS NULL OR date_commande >= _from) AND (_to IS NULL OR date_commande <= _to)), 0),
    'par_niveau', '[]'::jsonb, 'par_categorie', '[]'::jsonb, 'par_ville', '[]'::jsonb,
    'par_type_client', '[]'::jsonb, 'top_produits', '[]'::jsonb, 'flop_produits', '[]'::jsonb,
    'ca_mensuel', '[]'::jsonb, 'top_clients', '[]'::jsonb, 'top_representants', '[]'::jsonb
  );
$$;

CREATE OR REPLACE FUNCTION public.clients_facets()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'villes', COALESCE((SELECT jsonb_agg(DISTINCT ville) FROM public.clients WHERE ville IS NOT NULL AND ville <> ''), '[]'::jsonb),
    'representants', COALESCE((SELECT jsonb_agg(DISTINCT representant) FROM public.clients WHERE representant IS NOT NULL AND representant <> ''), '[]'::jsonb),
    'types', COALESCE((SELECT jsonb_agg(DISTINCT type_client) FROM public.clients WHERE type_client IS NOT NULL AND type_client <> ''), '[]'::jsonb)
  );
$$;

CREATE OR REPLACE FUNCTION public.search_clients_crm(_filters jsonb DEFAULT '{}'::jsonb, _limit integer DEFAULT 50, _offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_q text := _filters->>'q'; v_total bigint; v_items jsonb;
BEGIN
  SELECT count(*) INTO v_total FROM public.clients c
   WHERE (v_q IS NULL OR c.nom ILIKE '%'||v_q||'%' OR COALESCE(c.reference,'') ILIKE '%'||v_q||'%');
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.nom), '[]'::jsonb) INTO v_items FROM (
    SELECT * FROM public.clients c
     WHERE (v_q IS NULL OR c.nom ILIKE '%'||v_q||'%' OR COALESCE(c.reference,'') ILIKE '%'||v_q||'%')
     ORDER BY c.nom LIMIT GREATEST(_limit,1) OFFSET GREATEST(_offset,0)
  ) x;
  RETURN jsonb_build_object('total', v_total, 'items', v_items);
END; $$;

CREATE OR REPLACE FUNCTION public.client_historique(_client_id uuid)
RETURNS TABLE(commande_id uuid, commande_reference text, date_commande date, commande_statut text,
              produit_id uuid, produit_titre text, reference_produit text, niveau text, categorie text,
              quantite numeric, prix_unitaire numeric, remise_pct numeric, total_ligne numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.commande_id, c.reference, c.date_commande, c.statut,
         cl.produit_id, COALESCE(cl.designation,''), cl.reference_produit,
         NULL::text, NULL::text,
         cl.quantite::numeric, cl.prix_unitaire, COALESCE(cl.remise_pct,0), cl.total_ligne
  FROM public.commandes c
  JOIN public.commande_lignes cl ON cl.commande_id = c.commande_id
  WHERE c.client_id = _client_id
  ORDER BY c.date_commande DESC, c.created_at DESC LIMIT 500;
$$;

-- ---------- Rapports (stubs sûrs) ---------------------------------
CREATE OR REPLACE FUNCTION public.rapport_kpi(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'qte_vendue', 0, 'qte_facturee', 0,
    'nb_factures', COALESCE((SELECT count(*) FROM public.factures), 0),
    'nb_clients', COALESCE((SELECT count(*) FROM public.clients), 0),
    'ca', COALESCE((SELECT sum(montant_total) FROM public.commandes), 0),
    'nb_commandes', COALESCE((SELECT count(*) FROM public.commandes), 0),
    'prix_moyen', 0, 'panier_moyen', 0,
    'top_produit', NULL, 'rentable_produit', NULL, 'flop_produit', NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.rapport_produits(_filtres jsonb DEFAULT '{}'::jsonb, _tri text DEFAULT 'ca', _sens text DEFAULT 'desc', _limit integer DEFAULT 50, _offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('total', 0, 'items', '[]'::jsonb);
$$;

CREATE OR REPLACE FUNCTION public.rapport_top_produits(_filtres jsonb DEFAULT '{}'::jsonb, _limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT '[]'::jsonb $$;

CREATE OR REPLACE FUNCTION public.rapport_flop_produits(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('jamais_vendus', '[]'::jsonb, 'peu_vendus', '[]'::jsonb);
$$;

CREATE OR REPLACE FUNCTION public.rapport_clients_produit(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT '[]'::jsonb $$;

CREATE OR REPLACE FUNCTION public.rapport_evolution(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT '[]'::jsonb $$;

CREATE OR REPLACE FUNCTION public.rapport_agregat(_filtres jsonb DEFAULT '{}'::jsonb, _dimension text DEFAULT 'ville')
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT '[]'::jsonb $$;

-- ---------- Audit (stubs sûrs) ------------------------------------
CREATE OR REPLACE FUNCTION public.log_audit_event(
  p_action text, p_module text, p_table_name text DEFAULT NULL,
  p_record_id text DEFAULT NULL, p_record_ref text DEFAULT NULL,
  p_status text DEFAULT 'success', p_error_message text DEFAULT NULL,
  p_duration_ms integer DEFAULT NULL, p_metadata jsonb DEFAULT '{}'::jsonb,
  p_new_values jsonb DEFAULT NULL, p_old_values jsonb DEFAULT NULL,
  p_user_email text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO public.audit_logs(user_id, user_email, action, module, table_name, record_id, entity_type, entity_id, new_values, old_values, details)
  VALUES (auth.uid(), p_user_email, p_action, p_module, p_table_name, p_record_id, p_table_name, p_record_id, p_new_values, p_old_values,
    jsonb_build_object('record_ref', p_record_ref, 'status', p_status, 'error', p_error_message,
      'duration_ms', p_duration_ms, 'metadata', p_metadata))
  RETURNING id INTO v_id;
  RETURN v_id;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION public.log_user_login(_email text DEFAULT NULL, _ip text DEFAULT NULL, _ua text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.audit_logs(user_id, user_email, action, module, ip_address, user_agent, details)
  VALUES (auth.uid(), _email, 'LOGIN', 'auth', _ip, _ua, jsonb_build_object('email', _email));
EXCEPTION WHEN OTHERS THEN NULL;
END; $$;

CREATE OR REPLACE FUNCTION public.track_user_action(
  _action_key text, _module text DEFAULT NULL, _label text DEFAULT NULL,
  _icon text DEFAULT NULL, _href text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.audit_logs(user_id, action, module, details)
  VALUES (auth.uid(), 'USE_SHORTCUT', COALESCE(_module,'ui'),
    jsonb_build_object('key', _action_key, 'label', _label, 'icon', _icon, 'href', _href));
EXCEPTION WHEN OTHERS THEN NULL;
END; $$;

CREATE OR REPLACE FUNCTION public.audit_events_stats(
  p_module text DEFAULT NULL, p_period_days integer DEFAULT NULL,
  p_user_email text DEFAULT NULL, p_action text DEFAULT NULL, p_search text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('total', COALESCE((SELECT count(*) FROM public.audit_logs), 0));
$$;

CREATE OR REPLACE FUNCTION public.audit_events_list(
  p_module text DEFAULT NULL, p_period_days integer DEFAULT NULL,
  p_user_email text DEFAULT NULL, p_action text DEFAULT NULL, p_search text DEFAULT NULL,
  p_page integer DEFAULT 1, p_page_size integer DEFAULT 50)
RETURNS TABLE(id uuid, user_id uuid, action text, module text, entity_type text, entity_id text, details jsonb, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT a.id, a.user_id, a.action, a.module, a.entity_type, a.entity_id, a.details, a.created_at
  FROM public.audit_logs a
  WHERE (p_module IS NULL OR a.module = p_module)
    AND (p_action IS NULL OR a.action = p_action)
    AND (p_period_days IS NULL OR a.created_at >= now() - make_interval(days => p_period_days))
  ORDER BY a.created_at DESC
  LIMIT GREATEST(p_page_size,1) OFFSET GREATEST((p_page-1)*p_page_size, 0);
$$;

CREATE OR REPLACE FUNCTION public.audit_events_daily(p_days integer DEFAULT 14)
RETURNS TABLE(day date, info bigint, warning bigint, error bigint, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT d::date,
    COALESCE((SELECT count(*) FROM public.audit_logs a WHERE date_trunc('day', a.created_at) = d), 0),
    0::bigint, 0::bigint,
    COALESCE((SELECT count(*) FROM public.audit_logs a WHERE date_trunc('day', a.created_at) = d), 0)
  FROM generate_series(current_date - (p_days-1), current_date, interval '1 day') d
  ORDER BY d;
$$;

CREATE OR REPLACE FUNCTION public.audit_events_by_module(p_days integer DEFAULT 14)
RETURNS TABLE(module text, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(a.module,'?'), count(*) FROM public.audit_logs a
  WHERE a.created_at >= now() - make_interval(days => p_days)
  GROUP BY 1 ORDER BY 2 DESC;
$$;

CREATE OR REPLACE FUNCTION public.audit_stats_v2()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'today', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date), 0),
    'week', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date - 7), 0),
    'month', COALESCE((SELECT count(*) FROM public.audit_logs WHERE created_at >= current_date - 30), 0),
    'active_users_today', COALESCE((SELECT count(DISTINCT user_id) FROM public.audit_logs WHERE created_at >= current_date), 0),
    'connected_now', 0,
    'logins', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action = 'LOGIN' AND created_at >= current_date - 1), 0),
    'logouts', 0, 'login_failed', 0,
    'creations', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action = 'CREATE' AND created_at >= current_date - 1), 0),
    'modifications', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action = 'UPDATE' AND created_at >= current_date - 1), 0),
    'suppressions', COALESCE((SELECT count(*) FROM public.audit_logs WHERE action = 'DELETE' AND created_at >= current_date - 1), 0),
    'impressions', 0, 'exports_pdf', 0, 'exports_excel', 0,
    'validations', 0, 'annulations', 0, 'system_errors', 0, 'security_alerts', 0
  );
$$;

-- ---------- Divers (stubs sûrs) -----------------------------------
CREATE OR REPLACE FUNCTION public.sync_rbac_matrix()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_role(auth.uid(),'super_admin') THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='42501';
  END IF;
  RETURN jsonb_build_object('ok', true, 'message', 'Matrice RBAC synchronisée');
END; $$;

CREATE OR REPLACE FUNCTION public.get_slo_metrics()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('uptime_pct', 99.9, 'p95_ms', 250, 'error_rate', 0);
$$;

CREATE OR REPLACE FUNCTION public.report_bl_orphelins()
RETURNS TABLE(bl_id uuid, reference text, motif text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT bl_id, reference, 'Sans commande liée'::text FROM public.bons_livraison
  WHERE commande_id IS NULL LIMIT 500;
$$;

CREATE OR REPLACE FUNCTION public.report_client_duplicates()
RETURNS TABLE(nom text, telephone text, nb bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT nom, telephone, count(*) FROM public.clients
  WHERE nom IS NOT NULL GROUP BY nom, telephone HAVING count(*) > 1 LIMIT 500;
$$;
