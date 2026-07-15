
-- =========================================================
-- 4.1 Fonctions de calcul de soldes
-- =========================================================

CREATE OR REPLACE FUNCTION public.calcul_solde_client(
  _client_id uuid,
  _exercice_id uuid
) RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_report numeric := 0;
  v_factures numeric := 0;
  v_paiements numeric := 0;
  v_retours numeric := 0;
BEGIN
  -- Report à nouveau depuis les exercices précédents
  SELECT COALESCE(SUM(montant), 0) INTO v_report
  FROM public.soldes_ouverture_clients
  WHERE client_id = _client_id AND exercice_id = _exercice_id;

  -- Factures TTC (hors annulées) de l'exercice
  SELECT COALESCE(SUM(montant_total), 0) INTO v_factures
  FROM public.factures
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut <> 'annulee';

  -- Paiements valides de l'exercice
  SELECT COALESCE(SUM(montant), 0) INTO v_paiements
  FROM public.paiements
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut = 'valide';

  -- Retours valides (réduisent la dette)
  SELECT COALESCE(SUM(montant_total), 0) INTO v_retours
  FROM public.retours
  WHERE client_id = _client_id
    AND exercice_id = _exercice_id
    AND statut = 'valide';

  RETURN v_report + v_factures - v_paiements - v_retours;
END;
$$;

CREATE OR REPLACE FUNCTION public.calcul_solde_fournisseur(
  _fournisseur_id uuid,
  _exercice_id uuid
) RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_report numeric := 0;
  v_achats numeric := 0;
  v_paiements numeric := 0;
BEGIN
  SELECT COALESCE(SUM(montant), 0) INTO v_report
  FROM public.soldes_ouverture_fournisseurs
  WHERE fournisseur_id = _fournisseur_id AND exercice_id = _exercice_id;

  SELECT COALESCE(SUM(montant_total), 0) INTO v_achats
  FROM public.achats
  WHERE fournisseur_id = _fournisseur_id
    AND exercice_id = _exercice_id
    AND statut <> 'annule';

  -- Paiements fournisseurs = transactions type 'depense' rattachées à ce fournisseur (best-effort)
  SELECT COALESCE(SUM(montant), 0) INTO v_paiements
  FROM public.transactions
  WHERE exercice_id = _exercice_id
    AND type = 'depense'
    AND reference ILIKE '%' || _fournisseur_id::text || '%';

  RETURN v_report + v_achats - v_paiements;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calcul_solde_client(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calcul_solde_fournisseur(uuid, uuid) TO authenticated;

-- =========================================================
-- 4.2 Aperçu de clôture
-- =========================================================

CREATE OR REPLACE FUNCTION public.preview_cloture_exercice(
  _exercice_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exercice public.exercices%ROWTYPE;
  v_suivant public.exercices%ROWTYPE;
  v_clients_debiteurs int := 0;
  v_clients_crediteurs int := 0;
  v_fournisseurs_debiteurs int := 0;
  v_fournisseurs_crediteurs int := 0;
  v_total_clients_debit numeric := 0;
  v_total_clients_credit numeric := 0;
  v_total_fournisseurs_debit numeric := 0;
  v_total_fournisseurs_credit numeric := 0;
  v_blocages jsonb := '[]'::jsonb;
BEGIN
  IF NOT (public.has_role(auth.uid(), 'super_admin')
       OR public.has_role(auth.uid(), 'directeur_general')
       OR public.has_role(auth.uid(), 'comptable')) THEN
    RAISE EXCEPTION 'Accès refusé' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_exercice FROM public.exercices WHERE exercice_id = _exercice_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercice introuvable';
  END IF;

  -- Exercice suivant = premier dont date_debut > date_fin courant
  SELECT * INTO v_suivant
  FROM public.exercices
  WHERE date_debut > v_exercice.date_fin
  ORDER BY date_debut ASC
  LIMIT 1;

  -- Points bloquants : commandes non finalisées, factures brouillon, etc.
  IF EXISTS (
    SELECT 1 FROM public.commandes
    WHERE exercice_id = _exercice_id AND statut IN ('brouillon', 'en_attente')
  ) THEN
    v_blocages := v_blocages || jsonb_build_object(
      'code', 'COMMANDES_EN_ATTENTE',
      'severite', 'warning',
      'message', 'Des commandes sont encore en brouillon ou en attente'
    );
  END IF;

  IF v_suivant.exercice_id IS NULL THEN
    v_blocages := v_blocages || jsonb_build_object(
      'code', 'PAS_EXERCICE_SUIVANT',
      'severite', 'error',
      'message', 'Aucun exercice suivant n''existe. Créez-le avant de clôturer.'
    );
  END IF;

  -- Agrégation clients avec solde non nul
  WITH s AS (
    SELECT c.client_id, public.calcul_solde_client(c.client_id, _exercice_id) AS solde
    FROM public.clients c
  )
  SELECT
    COUNT(*) FILTER (WHERE solde > 0),
    COUNT(*) FILTER (WHERE solde < 0),
    COALESCE(SUM(solde) FILTER (WHERE solde > 0), 0),
    COALESCE(SUM(-solde) FILTER (WHERE solde < 0), 0)
  INTO v_clients_debiteurs, v_clients_crediteurs,
       v_total_clients_debit, v_total_clients_credit
  FROM s;

  -- Agrégation fournisseurs
  WITH s AS (
    SELECT f.fournisseur_id, public.calcul_solde_fournisseur(f.fournisseur_id, _exercice_id) AS solde
    FROM public.fournisseurs f
  )
  SELECT
    COUNT(*) FILTER (WHERE solde > 0),
    COUNT(*) FILTER (WHERE solde < 0),
    COALESCE(SUM(solde) FILTER (WHERE solde > 0), 0),
    COALESCE(SUM(-solde) FILTER (WHERE solde < 0), 0)
  INTO v_fournisseurs_debiteurs, v_fournisseurs_crediteurs,
       v_total_fournisseurs_debit, v_total_fournisseurs_credit
  FROM s;

  RETURN jsonb_build_object(
    'exercice', to_jsonb(v_exercice),
    'exercice_suivant', to_jsonb(v_suivant),
    'clients', jsonb_build_object(
      'debiteurs_count', v_clients_debiteurs,
      'crediteurs_count', v_clients_crediteurs,
      'total_debit', v_total_clients_debit,
      'total_credit', v_total_clients_credit
    ),
    'fournisseurs', jsonb_build_object(
      'debiteurs_count', v_fournisseurs_debiteurs,
      'crediteurs_count', v_fournisseurs_crediteurs,
      'total_debit', v_total_fournisseurs_debit,
      'total_credit', v_total_fournisseurs_credit
    ),
    'blocages', v_blocages,
    'peut_cloturer', NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_blocages) e
      WHERE e->>'severite' = 'error'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.preview_cloture_exercice(uuid) TO authenticated;

-- =========================================================
-- 4.3 Exécution de la clôture
-- =========================================================

CREATE OR REPLACE FUNCTION public.executer_cloture_exercice(
  _exercice_id uuid,
  _activer_suivant boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exercice public.exercices%ROWTYPE;
  v_suivant public.exercices%ROWTYPE;
  v_user_id uuid := auth.uid();
  v_nb_clients int := 0;
  v_nb_fournisseurs int := 0;
  v_journal_id uuid;
BEGIN
  IF NOT (public.has_role(v_user_id, 'super_admin')
       OR public.has_role(v_user_id, 'directeur_general')
       OR public.has_role(v_user_id, 'comptable')) THEN
    RAISE EXCEPTION 'Accès refusé' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_exercice FROM public.exercices
   WHERE exercice_id = _exercice_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercice introuvable';
  END IF;

  IF v_exercice.statut IN ('cloture', 'archive') THEN
    RAISE EXCEPTION 'Exercice déjà clôturé';
  END IF;

  SELECT * INTO v_suivant
  FROM public.exercices
  WHERE date_debut > v_exercice.date_fin
  ORDER BY date_debut ASC
  LIMIT 1
  FOR UPDATE;

  IF v_suivant.exercice_id IS NULL THEN
    RAISE EXCEPTION 'Aucun exercice suivant n''existe';
  END IF;

  -- Statut intermédiaire
  UPDATE public.exercices SET statut = 'cloture_en_cours'
   WHERE exercice_id = _exercice_id;

  -- Report des soldes clients (débiteurs ET créditeurs)
  INSERT INTO public.soldes_ouverture_clients (client_id, exercice_id, montant, exercice_origine_id)
  SELECT c.client_id, v_suivant.exercice_id, public.calcul_solde_client(c.client_id, _exercice_id), _exercice_id
  FROM public.clients c
  WHERE public.calcul_solde_client(c.client_id, _exercice_id) <> 0
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_nb_clients = ROW_COUNT;

  -- Report des soldes fournisseurs
  INSERT INTO public.soldes_ouverture_fournisseurs (fournisseur_id, exercice_id, montant, exercice_origine_id)
  SELECT f.fournisseur_id, v_suivant.exercice_id, public.calcul_solde_fournisseur(f.fournisseur_id, _exercice_id), _exercice_id
  FROM public.fournisseurs f
  WHERE public.calcul_solde_fournisseur(f.fournisseur_id, _exercice_id) <> 0
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_nb_fournisseurs = ROW_COUNT;

  -- Journal d'opération
  INSERT INTO public.exercice_cloture_journal
    (exercice_id, exercice_suivant_id, executed_by, nb_clients_reportes, nb_fournisseurs_reportes, details)
  VALUES
    (_exercice_id, v_suivant.exercice_id, v_user_id, v_nb_clients, v_nb_fournisseurs,
     jsonb_build_object('activer_suivant', _activer_suivant, 'executed_at', now()))
  RETURNING journal_id INTO v_journal_id;

  -- Basculement des statuts
  UPDATE public.exercices
     SET statut = 'cloture',
         is_actif = false,
         date_cloture = now(),
         cloture_par = v_user_id
   WHERE exercice_id = _exercice_id;

  IF _activer_suivant THEN
    -- Désactiver tout autre actif
    UPDATE public.exercices SET is_actif = false WHERE is_actif = true;
    UPDATE public.exercices
       SET statut = 'actif', is_actif = true
     WHERE exercice_id = v_suivant.exercice_id;
  END IF;

  RETURN jsonb_build_object(
    'journal_id', v_journal_id,
    'nb_clients_reportes', v_nb_clients,
    'nb_fournisseurs_reportes', v_nb_fournisseurs,
    'exercice_actif_id', CASE WHEN _activer_suivant THEN v_suivant.exercice_id ELSE NULL END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.executer_cloture_exercice(uuid, boolean) TO authenticated;

-- Contraintes d'unicité pour ON CONFLICT
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'soldes_ouv_client_uk') THEN
    CREATE UNIQUE INDEX soldes_ouv_client_uk
      ON public.soldes_ouverture_clients(client_id, exercice_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'soldes_ouv_fourn_uk') THEN
    CREATE UNIQUE INDEX soldes_ouv_fourn_uk
      ON public.soldes_ouverture_fournisseurs(fournisseur_id, exercice_id);
  END IF;
END $$;
