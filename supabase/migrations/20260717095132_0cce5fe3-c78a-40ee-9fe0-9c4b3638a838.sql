-- ============================================================================
-- LOT 1 : Durcissement RBAC — Module TOURNÉES
-- ============================================================================
-- Contexte : audit du 2026-07-17 → 73+ fonctions SECURITY DEFINER dans public
-- s'exécutent sans contrôle RBAC interne, contournant potentiellement RLS.
-- Ce lot instrumente les 3 RPC mutantes du module Tournées et crée le helper
-- has_permission() qui sera réutilisé par les lots suivants.
-- ============================================================================

-- 1. Helper universel de vérification de permission
--    Aligne sa logique sur list_user_permissions() : rôles RBAC + rôles legacy
--    (user_roles) + héritage via rbac_role_ancestors + court-circuit super_admin.
CREATE OR REPLACE FUNCTION public.has_permission(_user_id uuid, _permission_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    -- Super admin : court-circuit (via user_roles legacy ou rbac_user_roles)
    EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = _user_id AND ur.role = 'super_admin'::public.app_role
    )
    OR EXISTS (
      SELECT 1
      FROM public.rbac_user_roles ur
      JOIN public.rbac_roles r ON r.role_id = ur.role_id
      WHERE ur.user_id = _user_id AND r.code = 'super_admin' AND r.actif
    )
    -- Permission attribuée via rbac_user_roles + héritage
    OR EXISTS (
      SELECT 1
      FROM public.rbac_user_roles ur
      JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
      JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
      JOIN public.rbac_role_permissions rp
        ON rp.role_id = anc.role_id
       AND rp.permission_code = _permission_code
      WHERE ur.user_id = _user_id AND rp.accorde = true
    )
    -- Permission attribuée via user_roles legacy → rbac_roles + héritage
    OR EXISTS (
      SELECT 1
      FROM public.user_roles ur
      JOIN public.rbac_roles r ON r.code = ur.role::text AND r.actif
      JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
      JOIN public.rbac_role_permissions rp
        ON rp.role_id = anc.role_id
       AND rp.permission_code = _permission_code
      WHERE ur.user_id = _user_id AND rp.accorde = true
    );
$$;

REVOKE ALL ON FUNCTION public.has_permission(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_permission(uuid, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.has_permission(uuid, text) IS
  'Vérifie qu''un utilisateur possède la permission RBAC indiquée. Court-circuit super_admin. À utiliser comme préambule de toute RPC SECURITY DEFINER sensible.';

-- 2. Durcissement des 3 RPC mutantes du module Tournées
CREATE OR REPLACE FUNCTION public.finaliser_tournee(_tournee_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE v_type text; v_statut text;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'tournees.valider') THEN
    RAISE EXCEPTION 'Accès refusé : permission tournees.valider requise'
      USING ERRCODE = '42501';
  END IF;

  SELECT type_tournee, statut INTO v_type, v_statut
  FROM public.tournees WHERE tournee_id = _tournee_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION 'Tournée introuvable'; END IF;
  IF v_statut NOT IN ('preparee','brouillon') THEN
    RAISE EXCEPTION 'Tournée déjà validée (statut=%)', v_statut;
  END IF;

  INSERT INTO public.livsuivi_commandes(commande_id, tournee_id, type_livraison, ville_destination, livreur_nom, vehicule, statut, nb_cartons)
  SELECT DISTINCT c.commande_id, _tournee_id,
    COALESCE(v_type,'direct'),
    COALESCE(col.ville_livraison, col.ville_destination),
    col.livreur_nom, col.vehicule, 'preparee', col.nb_cartons
  FROM public.colis col
  JOIN public.commandes c ON c.commande_id = col.commande_id
  WHERE col.tournee_id = _tournee_id
    AND NOT EXISTS (
      SELECT 1 FROM public.livsuivi_commandes ls
      WHERE ls.tournee_id = _tournee_id AND ls.commande_id = col.commande_id
    );

  UPDATE public.tournees SET statut = 'en_cours' WHERE tournee_id = _tournee_id;
  RETURN jsonb_build_object('tournee_id', _tournee_id, 'statut', 'en_cours');
END;
$function$;

CREATE OR REPLACE FUNCTION public.cloturer_tournee(_tournee_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'tournees.cloturer') THEN
    RAISE EXCEPTION 'Accès refusé : permission tournees.cloturer requise'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.tournees SET statut = 'terminee' WHERE tournee_id = _tournee_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.annuler_validation_tournee(_tournee_id uuid, _motif text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF NOT public.has_permission(auth.uid(), 'tournees.annuler_validation') THEN
    RAISE EXCEPTION 'Accès refusé : permission tournees.annuler_validation requise'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.tournees SET
    validation_statut = 'brouillon',
    validation_commentaire = COALESCE(_motif, validation_commentaire),
    validation_at = NULL,
    validation_by = NULL
  WHERE tournee_id = _tournee_id;
END;
$function$;