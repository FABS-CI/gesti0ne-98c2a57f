
-- Mutations ---------------------------------------------------------

CREATE OR REPLACE FUNCTION public.preview_cloture_exercice(_exercice_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'exercices.cloturer') THEN
    RAISE EXCEPTION 'Permission refusée : exercices.cloturer' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'exercice_id', _exercice_id,
    'nb_ecritures', (SELECT count(*) FROM public.ecritures_comptables WHERE exercice_id = _exercice_id),
    'nb_factures', (SELECT count(*) FROM public.factures WHERE exercice_id = _exercice_id),
    'nb_commandes', (SELECT count(*) FROM public.commandes WHERE exercice_id = _exercice_id),
    'total_ca', COALESCE((SELECT sum(montant_total) FROM public.commandes WHERE exercice_id = _exercice_id), 0),
    'total_paye', COALESCE((SELECT sum(montant_paye) FROM public.factures WHERE exercice_id = _exercice_id), 0),
    'total_impaye', COALESCE((SELECT sum(montant_total - COALESCE(montant_paye,0)) FROM public.factures WHERE exercice_id = _exercice_id AND statut <> 'payee'), 0),
    'anomalies', '[]'::jsonb
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.executer_cloture_exercice(_exercice_id uuid, _activer_suivant boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_source public.exercices_comptables%ROWTYPE;
  v_cible  public.exercices_comptables%ROWTYPE;
  v_nb_clients int := 0;
  v_montant_clients numeric := 0;
  v_nb_fours int := 0;
  v_montant_fours numeric := 0;
  v_user_email text;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'exercices.cloturer') THEN
    RAISE EXCEPTION 'Permission refusée : exercices.cloturer' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_source FROM public.exercices_comptables WHERE exercice_id = _exercice_id;
  IF v_source.exercice_id IS NULL THEN RAISE EXCEPTION 'Exercice introuvable'; END IF;
  IF v_source.statut = 'cloture' THEN RAISE EXCEPTION 'Exercice déjà clôturé'; END IF;

  SELECT * INTO v_cible FROM public.exercices_comptables
   WHERE date_debut > v_source.date_fin ORDER BY date_debut ASC LIMIT 1;

  IF v_cible.exercice_id IS NOT NULL THEN
    WITH soldes AS (
      SELECT client_id, COALESCE(SUM(montant_total - COALESCE(montant_paye,0)),0) AS solde
      FROM public.factures
      WHERE exercice_id = _exercice_id AND client_id IS NOT NULL AND statut <> 'payee'
      GROUP BY client_id
      HAVING COALESCE(SUM(montant_total - COALESCE(montant_paye,0)),0) <> 0
    ), ins AS (
      INSERT INTO public.soldes_ouverture_clients (client_id, exercice_id, montant)
      SELECT client_id, v_cible.exercice_id, solde FROM soldes
      ON CONFLICT DO NOTHING RETURNING montant
    )
    SELECT COUNT(*), COALESCE(SUM(montant),0) INTO v_nb_clients, v_montant_clients FROM ins;

    WITH soldes_f AS (
      SELECT fournisseur_id, COALESCE(SUM(montant),0) AS solde
      FROM public.achats
      WHERE exercice_id = _exercice_id AND fournisseur_id IS NOT NULL
        AND statut NOT IN ('paye','annule')
      GROUP BY fournisseur_id
      HAVING COALESCE(SUM(montant),0) <> 0
    ), ins2 AS (
      INSERT INTO public.soldes_ouverture_fournisseurs (fournisseur_id, exercice_id, montant)
      SELECT fournisseur_id, v_cible.exercice_id, solde FROM soldes_f
      ON CONFLICT DO NOTHING RETURNING montant
    )
    SELECT COUNT(*), COALESCE(SUM(montant),0) INTO v_nb_fours, v_montant_fours FROM ins2;
  END IF;

  UPDATE public.exercices_comptables
     SET statut = 'cloture', cloture_le = now(), is_actif = false, updated_at = now()
   WHERE exercice_id = _exercice_id;

  IF _activer_suivant AND v_cible.exercice_id IS NOT NULL THEN
    UPDATE public.exercices_comptables SET is_actif = false WHERE is_actif = true;
    UPDATE public.exercices_comptables
       SET is_actif = true, statut = 'actif', updated_at = now()
     WHERE exercice_id = v_cible.exercice_id;
  END IF;

  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.exercice_cloture_journal (
    exercice_source_id, exercice_cible_id, date_cloture, cloture_par,
    nb_clients_reportes, montant_total_clients,
    nb_fournisseurs_reportes, montant_total_fournisseurs, details
  ) VALUES (
    _exercice_id, v_cible.exercice_id, now(), COALESCE(v_user_email, auth.uid()::text),
    v_nb_clients, v_montant_clients, v_nb_fours, v_montant_fours,
    jsonb_build_object('activer_suivant', _activer_suivant)
  );

  RETURN jsonb_build_object(
    'exercice_source_id', _exercice_id,
    'exercice_cible_id', v_cible.exercice_id,
    'nb_clients_reportes', v_nb_clients,
    'montant_total_clients', v_montant_clients,
    'nb_fournisseurs_reportes', v_nb_fours,
    'montant_total_fournisseurs', v_montant_fours
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.recalculer_solde_client(_client_id uuid)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_solde numeric;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'exercices.modifier') THEN
    RAISE EXCEPTION 'Permission refusée : exercices.modifier' USING ERRCODE = '42501';
  END IF;
  SELECT COALESCE(sum(montant_total - COALESCE(montant_paye,0)), 0) INTO v_solde
  FROM public.factures WHERE client_id = _client_id AND statut IN ('impayee','partielle');
  UPDATE public.clients SET solde = v_solde WHERE client_id = _client_id;
  RETURN v_solde;
END; $function$;

CREATE OR REPLACE FUNCTION public.recalculer_soldes_global_clients()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE r record; v_n int := 0;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'exercices.modifier') THEN
    RAISE EXCEPTION 'Permission refusée : exercices.modifier' USING ERRCODE = '42501';
  END IF;
  FOR r IN SELECT client_id FROM public.clients LOOP
    -- Appel direct sans re-check (déjà autorisé)
    UPDATE public.clients c SET solde = (
      SELECT COALESCE(sum(montant_total - COALESCE(montant_paye,0)), 0)
      FROM public.factures WHERE client_id = r.client_id AND statut IN ('impayee','partielle')
    ) WHERE c.client_id = r.client_id;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END; $function$;

-- Lectures sensibles -----------------------------------------------

CREATE OR REPLACE FUNCTION public.compta_balance(p_from date DEFAULT NULL, p_to date DEFAULT NULL, p_exercice_id uuid DEFAULT NULL)
RETURNS TABLE(numero_compte text, libelle text, debit numeric, credit numeric, solde numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'comptabilite.voir') THEN
    RAISE EXCEPTION 'Permission refusée : comptabilite.voir' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
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
END; $function$;

CREATE OR REPLACE FUNCTION public.factures_impayees_client(_client_id uuid)
RETURNS TABLE(facture_id uuid, reference text, date_facture date, montant_total numeric, montant_paye numeric, solde numeric, statut text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'comptabilite.voir') THEN
    RAISE EXCEPTION 'Permission refusée : comptabilite.voir' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT f.facture_id, f.reference, f.date_facture, f.montant_total, COALESCE(f.montant_paye,0),
         (f.montant_total - COALESCE(f.montant_paye,0))::numeric AS solde, f.statut
  FROM public.factures f
  WHERE f.client_id = _client_id AND f.statut IN ('impayee','partielle')
  ORDER BY f.date_facture ASC;
END; $function$;

CREATE OR REPLACE FUNCTION public.exercices_comparatif(_exercice_ids uuid[])
RETURNS TABLE(exercice_id uuid, libelle text, ca numeric, nb_commandes bigint, nb_factures bigint, montant_paye numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'comptabilite.voir') THEN
    RAISE EXCEPTION 'Permission refusée : comptabilite.voir' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT ex.exercice_id, ex.libelle,
    COALESCE((SELECT sum(montant_total) FROM public.commandes c WHERE c.exercice_id = ex.exercice_id), 0),
    COALESCE((SELECT count(*) FROM public.commandes c WHERE c.exercice_id = ex.exercice_id), 0),
    COALESCE((SELECT count(*) FROM public.factures f WHERE f.exercice_id = ex.exercice_id), 0),
    COALESCE((SELECT sum(montant_paye) FROM public.factures f WHERE f.exercice_id = ex.exercice_id), 0)
  FROM public.exercices_comptables ex
  WHERE ex.exercice_id = ANY(_exercice_ids)
  ORDER BY ex.date_debut;
END; $function$;

CREATE OR REPLACE FUNCTION public.audit_compta_factures_paiements()
RETURNS TABLE(type text, facture_id uuid, reference text, detail text, montant numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'comptabilite.voir') THEN
    RAISE EXCEPTION 'Permission refusée : comptabilite.voir' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT 'surpayee'::text, f.facture_id, f.reference, 'Trop-perçu'::text, (f.montant_paye - f.montant_total)::numeric
  FROM public.factures f WHERE COALESCE(f.montant_paye,0) > f.montant_total LIMIT 500;
END; $function$;

CREATE OR REPLACE FUNCTION public.audit_compta_soldes_clients()
RETURNS TABLE(client_id uuid, nom text, solde_calcule numeric, solde_stocke numeric, ecart numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'comptabilite.voir') THEN
    RAISE EXCEPTION 'Permission refusée : comptabilite.voir' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
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
END; $function$;
