
CREATE OR REPLACE FUNCTION public.supprimer_proforma_definitif(_proforma_id uuid, _motif text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _p public.proformas%ROWTYPE;
  _user uuid := auth.uid();
  _email text;
BEGIN
  IF _user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO _p FROM public.proformas WHERE proforma_id = _proforma_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Proforma introuvable' USING ERRCODE = 'P0002';
  END IF;

  IF _p.statut IN ('transformee','facturee') THEN
    RAISE EXCEPTION 'Suppression interdite: proforma % déjà transformée en facture', _p.reference
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT email INTO _email FROM auth.users WHERE id = _user;

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (_user, _email, 'delete_proforma_definitif', 'proformas', _proforma_id::text,
          to_jsonb(_p),
          jsonb_build_object('motif', _motif, 'role', 'super_admin', 'reference', _p.reference));

  DELETE FROM public.proforma_lignes WHERE proforma_id = _proforma_id;
  DELETE FROM public.proformas WHERE proforma_id = _proforma_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.supprimer_facture_definitif(_facture_id uuid, _motif text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _f public.factures%ROWTYPE;
  _user uuid := auth.uid();
  _email text;
  _nb_paie int;
  _nb_fne int;
BEGIN
  IF _user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO _f FROM public.factures WHERE facture_id = _facture_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Facture introuvable' USING ERRCODE = 'P0002';
  END IF;

  IF COALESCE(_f.montant_paye,0) > 0 OR _f.statut IN ('payee','partielle') THEN
    RAISE EXCEPTION 'Suppression interdite: facture % réglée ou partiellement payée', _f.reference
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT count(*) INTO _nb_paie FROM public.paiements WHERE facture_id = _facture_id;
  IF _nb_paie > 0 THEN
    RAISE EXCEPTION 'Suppression interdite: paiements enregistrés sur la facture %', _f.reference
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT count(*) INTO _nb_fne FROM public.fne_factures
    WHERE facture_id = _facture_id
      AND statut IN ('valide','soumis','submitted','validated','accepted');
  IF _nb_fne > 0 THEN
    RAISE EXCEPTION 'Suppression interdite: facture % déjà transmise à la FNE', _f.reference
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT email INTO _email FROM auth.users WHERE id = _user;

  INSERT INTO public.audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (_user, _email, 'delete_facture_definitif', 'factures', _facture_id::text,
          to_jsonb(_f),
          jsonb_build_object('motif', _motif, 'role', 'super_admin', 'reference', _f.reference));

  DELETE FROM public.fne_factures WHERE facture_id = _facture_id;
  UPDATE public.bons_retour SET facture_id = NULL WHERE facture_id = _facture_id;
  UPDATE public.retours SET facture_id = NULL WHERE facture_id = _facture_id;
  DELETE FROM public.factures WHERE facture_id = _facture_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.supprimer_proforma_definitif(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.supprimer_facture_definitif(uuid, text) TO authenticated;
