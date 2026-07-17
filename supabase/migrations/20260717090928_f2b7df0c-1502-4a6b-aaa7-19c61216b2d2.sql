
-- 1) annuler_inventaire
CREATE OR REPLACE FUNCTION public.annuler_inventaire(_inventaire_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_statut text;
BEGIN
  PERFORM public.assert_permission('inventaires.creer');
  SELECT statut INTO v_statut FROM public.inventaires WHERE inventaire_id = _inventaire_id;
  IF v_statut IS NULL THEN
    RAISE EXCEPTION 'Inventaire introuvable';
  END IF;
  IF v_statut IN ('valide','regularise','annule') THEN
    RAISE EXCEPTION 'Inventaire non annulable (statut: %)', v_statut;
  END IF;
  UPDATE public.inventaires
     SET statut = 'annule', updated_at = now()
   WHERE inventaire_id = _inventaire_id;
END;
$$;

-- 2) confirmer_achat
CREATE OR REPLACE FUNCTION public.confirmer_achat(_achat_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_statut text;
BEGIN
  PERFORM public.assert_permission('achats.receptionner');
  SELECT statut INTO v_statut FROM public.achats WHERE achat_id = _achat_id;
  IF v_statut IS NULL THEN
    RAISE EXCEPTION 'Achat introuvable';
  END IF;
  IF v_statut NOT IN ('brouillon','en_attente','en_attente_validation') THEN
    RAISE EXCEPTION 'Achat non confirmable (statut actuel: %)', v_statut;
  END IF;
  UPDATE public.achats
     SET statut = 'confirme', updated_at = now()
   WHERE achat_id = _achat_id;
END;
$$;

-- 3) executer_cloture_exercice
CREATE OR REPLACE FUNCTION public.executer_cloture_exercice(
  _exercice_id uuid,
  _activer_suivant boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_source public.exercices_comptables%ROWTYPE;
  v_cible  public.exercices_comptables%ROWTYPE;
  v_nb_clients int := 0;
  v_montant_clients numeric := 0;
  v_nb_fours int := 0;
  v_montant_fours numeric := 0;
  v_user_email text;
BEGIN
  PERFORM public.assert_permission('exercices.cloturer');

  SELECT * INTO v_source FROM public.exercices_comptables WHERE exercice_id = _exercice_id;
  IF v_source.exercice_id IS NULL THEN
    RAISE EXCEPTION 'Exercice introuvable';
  END IF;
  IF v_source.statut = 'cloture' THEN
    RAISE EXCEPTION 'Exercice déjà clôturé';
  END IF;

  -- Exercice cible = premier exercice qui commence après la fin du source
  SELECT * INTO v_cible
    FROM public.exercices_comptables
   WHERE date_debut > v_source.date_fin
   ORDER BY date_debut ASC
   LIMIT 1;

  -- Report soldes clients (impayés)
  IF v_cible.exercice_id IS NOT NULL THEN
    WITH soldes AS (
      SELECT client_id,
             COALESCE(SUM(montant_total - COALESCE(montant_paye,0)),0) AS solde
        FROM public.factures
       WHERE exercice_id = _exercice_id
         AND client_id IS NOT NULL
         AND statut <> 'payee'
       GROUP BY client_id
      HAVING COALESCE(SUM(montant_total - COALESCE(montant_paye,0)),0) <> 0
    ), ins AS (
      INSERT INTO public.soldes_ouverture_clients (client_id, exercice_id, montant)
      SELECT client_id, v_cible.exercice_id, solde FROM soldes
      ON CONFLICT DO NOTHING
      RETURNING montant
    )
    SELECT COUNT(*), COALESCE(SUM(montant),0) INTO v_nb_clients, v_montant_clients FROM ins;

    -- Report soldes fournisseurs (à partir des achats non payés)
    WITH soldes_f AS (
      SELECT fournisseur_id,
             COALESCE(SUM(montant),0) AS solde
        FROM public.achats
       WHERE exercice_id = _exercice_id
         AND fournisseur_id IS NOT NULL
         AND statut NOT IN ('paye','annule')
       GROUP BY fournisseur_id
      HAVING COALESCE(SUM(montant),0) <> 0
    ), ins2 AS (
      INSERT INTO public.soldes_ouverture_fournisseurs (fournisseur_id, exercice_id, montant)
      SELECT fournisseur_id, v_cible.exercice_id, solde FROM soldes_f
      ON CONFLICT DO NOTHING
      RETURNING montant
    )
    SELECT COUNT(*), COALESCE(SUM(montant),0) INTO v_nb_fours, v_montant_fours FROM ins2;
  END IF;

  -- Clôture
  UPDATE public.exercices_comptables
     SET statut = 'cloture', cloture_le = now(), is_actif = false, updated_at = now()
   WHERE exercice_id = _exercice_id;

  -- Activation de l'exercice cible si demandé
  IF _activer_suivant AND v_cible.exercice_id IS NOT NULL THEN
    UPDATE public.exercices_comptables SET is_actif = false WHERE is_actif = true;
    UPDATE public.exercices_comptables
       SET is_actif = true, statut = 'actif', updated_at = now()
     WHERE exercice_id = v_cible.exercice_id;
  END IF;

  -- Journal
  SELECT email INTO v_user_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.exercice_cloture_journal (
    exercice_source_id, exercice_cible_id, date_cloture, cloture_par,
    nb_clients_reportes, montant_total_clients,
    nb_fournisseurs_reportes, montant_total_fournisseurs,
    details
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
$$;

GRANT EXECUTE ON FUNCTION public.annuler_inventaire(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirmer_achat(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.executer_cloture_exercice(uuid, boolean) TO authenticated;
