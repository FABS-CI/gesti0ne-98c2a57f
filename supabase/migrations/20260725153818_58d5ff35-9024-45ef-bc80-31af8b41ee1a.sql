
-- Batch decision RPC
CREATE OR REPLACE FUNCTION public.approbation_decider_lot(
  p_ids uuid[],
  p_decision text,
  p_commentaire text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_ok int := 0;
  v_ko int := 0;
  v_errors jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;
  IF p_decision NOT IN ('approuve','rejete') THEN
    RAISE EXCEPTION 'Décision invalide: %', p_decision;
  END IF;
  IF p_ids IS NULL OR array_length(p_ids,1) IS NULL THEN
    RETURN jsonb_build_object('ok',0,'ko',0,'errors','[]'::jsonb);
  END IF;

  FOREACH v_id IN ARRAY p_ids LOOP
    BEGIN
      PERFORM public.approbation_decider(v_id, p_decision, p_commentaire);
      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN
      v_ko := v_ko + 1;
      v_errors := v_errors || jsonb_build_object('id', v_id, 'error', SQLERRM);
    END;
  END LOOP;

  RETURN jsonb_build_object('ok', v_ok, 'ko', v_ko, 'errors', v_errors);
END;
$$;

GRANT EXECUTE ON FUNCTION public.approbation_decider_lot(uuid[], text, text) TO authenticated;

-- Delegation RPC
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
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Non authentifié';
  END IF;

  SELECT * INTO v_row FROM public.workflow_approvals WHERE id = p_approbation_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Demande introuvable';
  END IF;
  IF v_row.statut <> 'en_attente' THEN
    RAISE EXCEPTION 'Seules les demandes en attente peuvent être déléguées';
  END IF;

  SELECT COALESCE(nom_complet, email) INTO v_actor_name FROM public.profiles WHERE id = v_actor;
  SELECT COALESCE(nom_complet, email) INTO v_delegataire_name FROM public.profiles WHERE id = p_delegataire_id;

  IF v_delegataire_name IS NULL THEN
    RAISE EXCEPTION 'Délégataire introuvable';
  END IF;

  v_hist := COALESCE(v_row.historique, '[]'::jsonb) || jsonb_build_object(
    'at', now(),
    'action', 'delegation',
    'by', v_actor,
    'by_name', v_actor_name,
    'to', p_delegataire_id,
    'to_name', v_delegataire_name,
    'commentaire', p_commentaire,
    'expire_at', p_expire_at
  );

  UPDATE public.workflow_approvals
  SET
    metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object(
        'delegataire_id', p_delegataire_id,
        'delegataire_nom', v_delegataire_name,
        'delegation_expire_at', p_expire_at,
        'delegue_par', v_actor_name,
        'delegue_at', now()
      ),
    historique = v_hist,
    updated_at = now()
  WHERE id = p_approbation_id;

  -- Notify delegataire (best effort)
  BEGIN
    INSERT INTO public.notifications (user_id, titre, message, type, module, lien)
    VALUES (
      p_delegataire_id,
      'Approbation déléguée',
      format('%s vous a délégué la demande %s', COALESCE(v_actor_name,'Un utilisateur'), COALESCE(v_row.reference, p_approbation_id::text)),
      'info',
      'approbations',
      '/approbations'
    );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.approbation_deleguer(uuid, uuid, text, timestamptz) TO authenticated;
