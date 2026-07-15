
ALTER TABLE public.bons_livraison
  ADD COLUMN IF NOT EXISTS annule_at timestamptz,
  ADD COLUMN IF NOT EXISTS annule_par uuid,
  ADD COLUMN IF NOT EXISTS annule_par_nom text,
  ADD COLUMN IF NOT EXISTS annulation_motif text;

CREATE OR REPLACE FUNCTION public.annuler_colisage(_bl_id uuid, _motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_bl public.bons_livraison; v_user uuid := auth.uid(); v_email text;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_bl FROM public.bons_livraison WHERE bl_id=_bl_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de livraison introuvable'; END IF;
  IF NOT public.has_role(v_user,'super_admin') THEN
    IF v_bl.statut NOT IN ('a_preparer','colisage_en_cours') THEN
      RAISE EXCEPTION 'Impossible d''annuler ce colisage car il est déjà pris en charge par le service logistique.'
        USING ERRCODE='check_violation';
    END IF;
  END IF;
  DELETE FROM public.colis WHERE bl_id=_bl_id;
  UPDATE public.bons_livraison
    SET statut='annule',
        annule_at=now(),
        annule_par=v_user,
        annule_par_nom=COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'),
        annulation_motif=_motif,
        updated_at=now()
    WHERE bl_id=_bl_id;
  SELECT email INTO v_email FROM auth.users WHERE id=v_user;
  INSERT INTO public.audit_logs(user_id,user_email,action,table_name,record_id,old_values,new_values)
  VALUES (v_user,COALESCE(v_email,''),'colisage_annule','bons_livraison',_bl_id::text,
    to_jsonb(v_bl),
    jsonb_build_object('motif',_motif,'reference',v_bl.reference,
      'role',CASE WHEN public.has_role(v_user,'super_admin') THEN 'super_admin' ELSE 'user' END));
END $$;

CREATE OR REPLACE FUNCTION public.supprimer_colisage(_bl_id uuid, _motif text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_bl public.bons_livraison; v_user uuid := auth.uid(); v_email text;
        v_is_admin boolean; v_owner boolean; v_has_colis boolean;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Non authentifié' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_bl FROM public.bons_livraison WHERE bl_id=_bl_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bon de livraison introuvable'; END IF;
  v_is_admin := public.has_role(v_user,'super_admin');
  SELECT EXISTS(SELECT 1 FROM public.colis WHERE bl_id=_bl_id) INTO v_has_colis;
  SELECT EXISTS(SELECT 1 FROM public.colis WHERE bl_id=_bl_id AND responsable_id=v_user) INTO v_owner;
  IF NOT v_is_admin THEN
    IF v_bl.statut NOT IN ('a_preparer','annule') THEN
      RAISE EXCEPTION 'Suppression interdite: le colisage est déjà pris en charge.'
        USING ERRCODE='check_violation';
    END IF;
    IF v_has_colis AND NOT v_owner THEN
      RAISE EXCEPTION 'Suppression interdite: vous n''êtes pas l''auteur de ce colisage.'
        USING ERRCODE='42501';
    END IF;
  END IF;
  DELETE FROM public.colis WHERE bl_id=_bl_id;
  UPDATE public.bons_livraison SET statut='a_preparer', updated_at=now() WHERE bl_id=_bl_id;
  SELECT email INTO v_email FROM auth.users WHERE id=v_user;
  INSERT INTO public.audit_logs(user_id,user_email,action,table_name,record_id,old_values,new_values)
  VALUES (v_user,COALESCE(v_email,''),
    CASE WHEN v_is_admin THEN 'colisage_supprime_super_admin' ELSE 'colisage_supprime' END,
    'bons_livraison',_bl_id::text,
    to_jsonb(v_bl),
    jsonb_build_object('motif',_motif,'reference',v_bl.reference,
      'role',CASE WHEN v_is_admin THEN 'super_admin' ELSE 'user' END));
END $$;

GRANT EXECUTE ON FUNCTION public.annuler_colisage(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supprimer_colisage(uuid,text) TO authenticated;
