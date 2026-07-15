-- Suppression définitive d'un Bon de Commande (super_admin uniquement)
CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(
  _commande_id uuid,
  _motif text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _cmd commandes%ROWTYPE;
  _has_fact boolean;
  _has_bl boolean;
  _has_prof boolean;
  _has_retour boolean;
  _has_colis boolean;
  _user uuid := auth.uid();
  _email text;
BEGIN
  IF _user IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_role(_user, 'super_admin'::app_role) THEN
    RAISE EXCEPTION 'Suppression réservée au Super Administrateur' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO _cmd FROM commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bon de commande introuvable' USING ERRCODE = 'P0002';
  END IF;

  SELECT EXISTS(SELECT 1 FROM factures WHERE commande_id = _commande_id) INTO _has_fact;
  SELECT EXISTS(SELECT 1 FROM bons_livraison WHERE commande_id = _commande_id) INTO _has_bl;
  SELECT EXISTS(SELECT 1 FROM proformas WHERE commande_id = _commande_id) INTO _has_prof;
  SELECT EXISTS(SELECT 1 FROM retours WHERE commande_id = _commande_id) INTO _has_retour;
  SELECT EXISTS(SELECT 1 FROM colis WHERE commande_id = _commande_id) INTO _has_colis;

  IF _has_fact OR _has_bl OR _has_prof OR _has_retour OR _has_colis THEN
    RAISE EXCEPTION 'Suppression interdite : la commande % est déjà liée à d''autres documents (facture, BL, proforma, retour ou colis).', _cmd.reference
      USING ERRCODE = '23503';
  END IF;

  SELECT email INTO _email FROM auth.users WHERE id = _user;

  INSERT INTO audit_logs(user_id, user_email, action, table_name, record_id, old_values, new_values)
  VALUES (
    _user,
    _email,
    'delete_commande_definitif',
    'commandes',
    _commande_id::text,
    to_jsonb(_cmd),
    jsonb_build_object('motif', _motif, 'role', 'super_admin')
  );

  DELETE FROM commandes WHERE commande_id = _commande_id;
END;
$$;

REVOKE ALL ON FUNCTION public.supprimer_commande_definitif(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supprimer_commande_definitif(uuid, text) TO authenticated;