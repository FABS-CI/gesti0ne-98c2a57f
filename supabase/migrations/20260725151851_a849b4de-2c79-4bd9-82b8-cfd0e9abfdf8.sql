-- =========================================================
-- Moteur d'approbation générique : Paiements / Frais / Annulations
-- =========================================================

-- 1) RPC générique de création d'une demande d'approbation
CREATE OR REPLACE FUNCTION public.approbation_creer(
  p_module text,
  p_workflow_code text,
  p_entity_type text,
  p_entity_id uuid,
  p_reference text,
  p_montant numeric DEFAULT NULL,
  p_motif text DEFAULT NULL,
  p_urgence text DEFAULT 'normal',
  p_sla_heures integer DEFAULT 48,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_uid uuid := auth.uid();
  v_nom text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  SELECT COALESCE(nom_complet, email, v_uid::text)
    INTO v_nom FROM public.profiles WHERE id = v_uid;

  INSERT INTO public.workflow_approvals(
    module, workflow_code, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, commentaire,
    metadata, niveau_urgence, sla_deadline,
    simulation_financiere, historique
  ) VALUES (
    p_module, p_workflow_code, p_entity_type, p_entity_id, p_reference,
    'en_attente', v_uid, v_nom, p_motif,
    COALESCE(p_metadata,'{}'::jsonb) || jsonb_build_object('montant', p_montant),
    COALESCE(p_urgence,'normal'),
    now() + make_interval(hours => COALESCE(p_sla_heures,48)),
    jsonb_build_object('montant', p_montant),
    jsonb_build_array(jsonb_build_object(
      'at', now(), 'by', v_uid, 'action', 'creation', 'motif', p_motif
    ))
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.approbation_creer(text,text,text,uuid,text,numeric,text,text,integer,jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.approbation_creer(text,text,text,uuid,text,numeric,text,text,integer,jsonb) TO authenticated;

-- 2) RPC générique de décision (approuve / refuse) avec callbacks par module
CREATE OR REPLACE FUNCTION public.approbation_decider(
  p_approbation_id uuid,
  p_decision text,               -- 'approuve' | 'refuse'
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
  v_meta jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  IF p_decision NOT IN ('approuve','refuse') THEN
    RAISE EXCEPTION 'Décision invalide (approuve|refuse)';
  END IF;

  SELECT * INTO v_appr FROM public.workflow_approvals WHERE id = p_approbation_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Demande introuvable';
  END IF;
  IF v_appr.statut <> 'en_attente' THEN
    RAISE EXCEPTION 'Demande déjà statuée (%)', v_appr.statut;
  END IF;

  -- Contrôle de permission : super_admin OU permission granulaire
  IF NOT (
    public.has_role(v_uid, 'super_admin')
    OR public.has_role(v_uid, 'admin')
    OR (p_decision='approuve' AND public.has_permission(v_uid, 'approbations.valider'))
    OR (p_decision='refuse'   AND public.has_permission(v_uid, 'approbations.refuser'))
  ) THEN
    RAISE EXCEPTION 'Permission refusée pour statuer sur cette approbation';
  END IF;

  SELECT COALESCE(nom_complet, email, v_uid::text)
    INTO v_nom FROM public.profiles WHERE id = v_uid;

  v_new_statut := CASE WHEN p_decision='approuve' THEN 'approuve' ELSE 'refuse' END;

  UPDATE public.workflow_approvals
     SET statut = v_new_statut,
         approbateur_id = v_uid,
         approbateur_nom = v_nom,
         commentaire = COALESCE(p_commentaire, commentaire),
         decided_at = now(),
         decision_details = jsonb_build_object(
           'decision', p_decision, 'by', v_uid, 'at', now(), 'commentaire', p_commentaire
         ),
         historique = COALESCE(historique,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'at', now(), 'by', v_uid, 'action', p_decision, 'commentaire', p_commentaire
         )),
         updated_at = now()
   WHERE id = p_approbation_id;

  -- ===== Callbacks métier =====
  IF p_decision = 'approuve' THEN
    IF v_appr.module = 'paiements' THEN
      UPDATE public.paiements
         SET statut = 'valide',
             valide_par = v_uid, valide_le = now(),
             commentaire_validation = p_commentaire,
             updated_at = now()
       WHERE id = v_appr.entity_id;

    ELSIF v_appr.module = 'annulations' AND v_appr.entity_type = 'commande' THEN
      UPDATE public.commandes
         SET statut = 'annulee',
             updated_at = now()
       WHERE id = v_appr.entity_id;

    ELSIF v_appr.module = 'couts_logistiques' THEN
      -- pas de statut sur couts_logistiques : validation portée par workflow_approvals
      NULL;
    END IF;

  ELSE  -- refuse
    IF v_appr.module = 'paiements' THEN
      UPDATE public.paiements
         SET statut = 'rejete',
             rejete_par = v_uid, rejete_le = now(),
             motif_rejet = p_commentaire,
             updated_at = now()
       WHERE id = v_appr.entity_id;

    ELSIF v_appr.module = 'annulations' AND v_appr.entity_type = 'commande' THEN
      -- restaure l'état précédent stocké dans metadata.previous_statut
      UPDATE public.commandes
         SET statut = COALESCE(v_appr.metadata->>'previous_statut', 'brouillon'),
             updated_at = now()
       WHERE id = v_appr.entity_id;
    END IF;
  END IF;

  -- Notification demandeur
  INSERT INTO public.notifications(user_id, type, titre, message, lien, metadata)
  VALUES (
    v_appr.demandeur_id,
    'approbation_' || p_decision,
    'Demande ' || CASE WHEN p_decision='approuve' THEN 'approuvée' ELSE 'refusée' END,
    COALESCE(v_appr.reference, v_appr.module) || ' — ' || COALESCE(p_commentaire,''),
    '/approbations',
    jsonb_build_object('approbation_id', p_approbation_id, 'module', v_appr.module)
  );

  RETURN jsonb_build_object('ok', true, 'statut', v_new_statut);
END;
$$;

REVOKE ALL ON FUNCTION public.approbation_decider(uuid,text,text) FROM public;
GRANT EXECUTE ON FUNCTION public.approbation_decider(uuid,text,text) TO authenticated;

-- 3) Trigger : auto-création d'approbation à l'insertion d'un paiement en attente
CREATE OR REPLACE FUNCTION public.trg_paiement_creer_approbation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_urgence text;
BEGIN
  IF NEW.statut IS DISTINCT FROM 'en_attente' THEN
    RETURN NEW;
  END IF;

  v_urgence := CASE
    WHEN NEW.montant >= 1000000 THEN 'critique'
    WHEN NEW.montant >= 250000  THEN 'urgent'
    ELSE 'normal'
  END;

  INSERT INTO public.workflow_approvals(
    module, workflow_code, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, metadata,
    niveau_urgence, sla_deadline, simulation_financiere
  ) VALUES (
    'paiements','paiement_valider','paiement', NEW.id,
    COALESCE(NEW.reference, NEW.reference_paiement, NEW.id::text),
    'en_attente', COALESCE(NEW.cree_par, auth.uid()),
    (SELECT COALESCE(nom_complet,email) FROM public.profiles WHERE id = COALESCE(NEW.cree_par, auth.uid())),
    jsonb_build_object(
      'paiement_id', NEW.id, 'facture_id', NEW.facture_id,
      'montant', NEW.montant, 'mode', NEW.mode_paiement, 'client', NEW.client_nom
    ),
    v_urgence, now() + interval '48 hours',
    jsonb_build_object('montant', NEW.montant)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_paiement_auto_approbation ON public.paiements;
CREATE TRIGGER trg_paiement_auto_approbation
AFTER INSERT ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.trg_paiement_creer_approbation();

-- 4) Trigger : auto-création d'approbation à l'insertion d'un frais logistique
CREATE OR REPLACE FUNCTION public.trg_cout_logistique_creer_approbation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_urgence text;
BEGIN
  v_urgence := CASE
    WHEN NEW.montant >= 500000 THEN 'critique'
    WHEN NEW.montant >= 100000 THEN 'urgent'
    ELSE 'normal'
  END;

  INSERT INTO public.workflow_approvals(
    module, workflow_code, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, metadata,
    niveau_urgence, sla_deadline, simulation_financiere
  ) VALUES (
    'couts_logistiques','cout_logistique_valider','cout_logistique', NEW.id,
    COALESCE(NEW.reference, NEW.libelle, NEW.id::text),
    'en_attente', auth.uid(),
    (SELECT COALESCE(nom_complet,email) FROM public.profiles WHERE id = auth.uid()),
    jsonb_build_object(
      'cout_id', NEW.id, 'type', NEW.type, 'libelle', NEW.libelle,
      'montant', NEW.montant, 'tournee_id', NEW.tournee_id, 'livraison_id', NEW.livraison_id
    ),
    v_urgence, now() + interval '72 hours',
    jsonb_build_object('montant', NEW.montant)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cout_logistique_auto_approbation ON public.couts_logistiques;
CREATE TRIGGER trg_cout_logistique_auto_approbation
AFTER INSERT ON public.couts_logistiques
FOR EACH ROW EXECUTE FUNCTION public.trg_cout_logistique_creer_approbation();

-- 5) RPC : demander l'annulation d'une commande
CREATE OR REPLACE FUNCTION public.commande_demander_annulation(
  p_commande_id uuid,
  p_motif text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_cmd public.commandes%ROWTYPE;
  v_id uuid;
  v_urgence text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF COALESCE(p_motif,'') = '' THEN RAISE EXCEPTION 'Motif obligatoire'; END IF;

  SELECT * INTO v_cmd FROM public.commandes WHERE id = p_commande_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_cmd.statut IN ('annulee','annulation_en_attente') THEN
    RAISE EXCEPTION 'Commande déjà annulée ou en cours d''annulation';
  END IF;

  v_urgence := CASE
    WHEN COALESCE(v_cmd.montant_ttc, v_cmd.montant_total, 0) >= 1000000 THEN 'critique'
    WHEN COALESCE(v_cmd.montant_ttc, v_cmd.montant_total, 0) >= 250000  THEN 'urgent'
    ELSE 'normal'
  END;

  INSERT INTO public.workflow_approvals(
    module, workflow_code, entity_type, entity_id, reference,
    statut, demandeur_id, demandeur_nom, commentaire,
    metadata, niveau_urgence, sla_deadline, simulation_financiere
  ) VALUES (
    'annulations','commande_annuler','commande', v_cmd.id,
    COALESCE(v_cmd.reference, v_cmd.numero, v_cmd.id::text),
    'en_attente', v_uid,
    (SELECT COALESCE(nom_complet,email) FROM public.profiles WHERE id = v_uid),
    p_motif,
    jsonb_build_object(
      'commande_id', v_cmd.id,
      'previous_statut', v_cmd.statut,
      'montant_ttc', v_cmd.montant_ttc,
      'client', v_cmd.client_nom
    ),
    v_urgence, now() + interval '24 hours',
    jsonb_build_object('montant', v_cmd.montant_ttc)
  ) RETURNING id INTO v_id;

  UPDATE public.commandes
     SET statut = 'annulation_en_attente', updated_at = now()
   WHERE id = v_cmd.id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.commande_demander_annulation(uuid,text) FROM public;
GRANT EXECUTE ON FUNCTION public.commande_demander_annulation(uuid,text) TO authenticated;