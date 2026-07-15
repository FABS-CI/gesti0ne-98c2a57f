
CREATE OR REPLACE FUNCTION public.supprimer_fournisseur(_fournisseur_id uuid, _motif text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_user uuid := auth.uid(); v_email text; v_f public.fournisseurs; v_nb int;
BEGIN PERFORM public.assert_permission('fournisseurs.supprimer');
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_f FROM public.fournisseurs WHERE fournisseur_id=_fournisseur_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Fournisseur introuvable'; END IF;
  SELECT count(*) INTO v_nb FROM public.achats WHERE fournisseur_id=_fournisseur_id;
  IF v_nb > 0 THEN
    RAISE EXCEPTION 'Suppression interdite : % approvisionnement(s) lié(s). Désactivez le fournisseur à la place.', v_nb
      USING ERRCODE='foreign_key_violation';
  END IF;
  DELETE FROM public.fournisseurs WHERE fournisseur_id=_fournisseur_id;
  SELECT email INTO v_email FROM auth.users WHERE id=v_user;
  INSERT INTO public.audit_logs(user_id,user_email,action,table_name,record_id,old_values,new_values)
  VALUES (v_user,COALESCE(v_email,''),'fournisseur_supprime','fournisseurs',_fournisseur_id::text,to_jsonb(v_f),
    jsonb_build_object('motif',_motif));
  RETURN jsonb_build_object('fournisseur_id',_fournisseur_id,'raison_sociale',v_f.raison_sociale,'motif',_motif);
END;
$function$;
