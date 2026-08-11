ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS metadata JSONB;

CREATE OR REPLACE FUNCTION public.approbation_decider(
  p_approbation_id uuid,
  p_decision text,
  p_commentaire text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_appr public.workflow_approvals%ROWTYPE;
  v_nom text;
  v_new_statut text;
  v_is_approve boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;

  v_is_approve := p_decision IN ('approuve','approve','valider','valide');
  IF NOT v_is_approve AND p_decision NOT IN ('refuse','rejete','rejeter','refuser') THEN
    RAISE EXCEPTION 'Décision invalide';
  END IF;

  SELECT * INTO v_appr FROM public.workflow_approvals WHERE id = p_approbation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF v_appr.statut <> 'en_attente' THEN
    RAISE EXCEPTION 'Demande déjà statuée (%)', v_appr.statut;
  END IF;

  IF NOT (
    public.has_role_compat(v_uid, 'super_admin')
    OR public.has_role_compat(v_uid, 'admin')
    OR (v_is_approve     AND public.has_permission(v_uid, 'approbations.valider'))
    OR (NOT v_is_approve AND public.has_permission(v_uid, 'approbations.refuser'))
  ) THEN
    RAISE EXCEPTION 'Permission refusée';
  END IF;

  SELECT COALESCE(nom_complet, email, v_uid::text) INTO v_nom
    FROM public.profiles WHERE id = v_uid;

  v_new_statut := CASE WHEN v_is_approve THEN 'approuve' ELSE 'rejete' END;

  UPDATE public.workflow_approvals
     SET statut = v_new_statut,
         approbateur_id = v_uid,
         approbateur_nom = v_nom,
         commentaire = COALESCE(p_commentaire, commentaire),
         motif_refus = CASE WHEN NOT v_is_approve THEN p_commentaire ELSE motif_refus END,
         decided_at = now(),
         decision_details = jsonb_build_object(
           'decision', v_new_statut, 'by', v_uid, 'at', now(), 'commentaire', p_commentaire
         ),
         historique = COALESCE(historique,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'at', now(), 'by', v_uid, 'action', v_new_statut, 'commentaire', p_commentaire
         )),
         updated_at = now()
   WHERE id = p_approbation_id;

  IF v_is_approve THEN
    IF v_appr.module = 'paiements' THEN
      UPDATE public.paiements
         SET statut = 'valide', valide_par = v_uid, valide_le = now(),
             commentaire_validation = p_commentaire, updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'annulations' AND v_appr.entity_type = 'commande' THEN
      UPDATE public.commandes SET statut = 'annulee', updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'retour' THEN
      UPDATE public.retours SET statut = 'approuve', updated_at = now() WHERE id = v_appr.entity_id;
    END IF;
  ELSE
    IF v_appr.module = 'paiements' THEN
      UPDATE public.paiements
         SET statut = 'rejete', rejete_par = v_uid, rejete_le = now(),
             motif_rejet = p_commentaire, updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'annulations' AND v_appr.entity_type = 'commande' THEN
      UPDATE public.commandes
         SET statut = COALESCE(v_appr.metadata->>'previous_statut', 'brouillon'),
             updated_at = now()
       WHERE id = v_appr.entity_id;
    ELSIF v_appr.module = 'retour' THEN
      UPDATE public.retours SET statut = 'rejete', updated_at = now() WHERE id = v_appr.entity_id;
    END IF;
  END IF;

  INSERT INTO public.notifications(user_id, type_notification, titre, message, lien, metadata)
  VALUES (
    v_appr.demandeur_id,
    'approbation_' || v_new_statut,
    'Demande ' || CASE WHEN v_is_approve THEN 'approuvée' ELSE 'rejetée' END,
    COALESCE(v_appr.reference, v_appr.module) || COALESCE(' — ' || p_commentaire, ''),
    '/approbations',
    jsonb_build_object('approbation_id', p_approbation_id, 'module', v_appr.module)
  );

  RETURN jsonb_build_object('ok', true, 'statut', v_new_statut);
END;
$$;

CREATE OR REPLACE FUNCTION public.approbation_deleguer(
  p_approbation_id uuid,
  p_delegataire_id uuid,
  p_commentaire text DEFAULT NULL,
  p_expire_at timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.workflow_approvals%ROWTYPE;
  v_actor uuid := auth.uid();
  v_actor_name text;
  v_delegataire_name text;
  v_hist jsonb;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;

  SELECT * INTO v_row FROM public.workflow_approvals WHERE id = p_approbation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF v_row.statut <> 'en_attente' THEN RAISE EXCEPTION 'Seules les demandes en attente peuvent être déléguées'; END IF;

  SELECT COALESCE(nom_complet, email) INTO v_actor_name FROM public.profiles WHERE id = v_actor;
  SELECT COALESCE(nom_complet, email) INTO v_delegataire_name FROM public.profiles WHERE id = p_delegataire_id;

  IF v_delegataire_name IS NULL THEN RAISE EXCEPTION 'Délégataire introuvable'; END IF;

  v_hist := COALESCE(v_row.historique, '[]'::jsonb) || jsonb_build_object(
    'at', now(), 'action', 'delegation', 'by', v_actor, 'by_name', v_actor_name,
    'to', p_delegataire_id, 'to_name', v_delegataire_name, 'commentaire', p_commentaire, 'expire_at', p_expire_at
  );

  UPDATE public.workflow_approvals
  SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'delegataire_id', p_delegataire_id, 'delegataire_nom', v_delegataire_name,
        'delegation_expire_at', p_expire_at, 'delegue_par', v_actor_name, 'delegue_at', now()
      ),
      historique = v_hist,
      updated_at = now()
  WHERE id = p_approbation_id;

  BEGIN
    INSERT INTO public.notifications (user_id, titre, message, type_notification, module, lien, metadata)
    VALUES (
      p_delegataire_id,
      'Approbation déléguée',
      format('%s vous a délégué la demande %s', COALESCE(v_actor_name,'Un utilisateur'), COALESCE(v_row.reference, p_approbation_id::text)),
      'info',
      'approbations',
      '/approbations',
      jsonb_build_object('approbation_id', p_approbation_id, 'delegue_par', v_actor)
    );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END;
$$;
