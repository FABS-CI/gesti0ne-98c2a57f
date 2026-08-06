-- Correction des permissions pour l'ajustement de stock

-- 1. S'assurer que rbac3_can retourne true pour super_admin sur TOUT
CREATE OR REPLACE FUNCTION public.rbac3_can(_perm text, _user_id uuid DEFAULT auth.uid())
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_is_super boolean;
  v_has_perm boolean;
BEGIN
  IF _user_id IS NULL THEN RETURN false; END IF;

  -- Le super_admin peut TOUT faire
  SELECT EXISTS (
    SELECT 1 FROM public.rbac2_user_roles WHERE user_id = _user_id AND role_code = 'super_admin'
  ) INTO v_is_super;
  
  IF v_is_super THEN RETURN true; END IF;
  
  -- Sinon check permission spécifique (v3)
  SELECT EXISTS (
    SELECT 1 FROM public.rbac3_user_permissions 
    WHERE user_id = _user_id AND permission_code = _perm
  ) INTO v_has_perm;
  
  RETURN v_has_perm;
END; $$;

-- 2. Réparer ajuster_stock_depot pour qu'il fonctionne même si l'enregistrement stocks_depots n'existe pas encore
CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(
  _produit_id uuid, _depot_id uuid, _nouvelle_quantite numeric, _motif text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_ancienne numeric;
  v_delta numeric;
  v_user_nom text := public._current_user_display_name();
BEGIN
  -- 1) Vérification des permissions RBAC v3
  IF NOT public.rbac3_can('stocks.modifier') THEN
    RAISE EXCEPTION 'Permission refusée : stocks.modifier' USING ERRCODE = '42501';
  END IF;

  -- 2) Vérification de la portée (Scope Step 8)
  -- Seul super_admin a une portée globale. Les autres sont limités à leurs dépôts.
  IF NOT public.rbac3_can('super_admin') THEN
    IF NOT EXISTS (SELECT 1 FROM public.user_depots WHERE user_id = auth.uid() AND depot_id = _depot_id) THEN
      RAISE EXCEPTION 'Accès refusé : vous n''avez pas accès à ce dépôt' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- S'assurer que l'enregistrement existe
  INSERT INTO public.stocks_depots(produit_id, depot_id, quantite) 
  VALUES (_produit_id, _depot_id, 0)
  ON CONFLICT (produit_id, depot_id) DO NOTHING;

  SELECT quantite INTO v_ancienne FROM public.stocks_depots WHERE produit_id = _produit_id AND depot_id = _depot_id FOR UPDATE;
  
  v_delta := _nouvelle_quantite - COALESCE(v_ancienne, 0);

  UPDATE public.stocks_depots 
  SET quantite = _nouvelle_quantite, updated_at = now() 
  WHERE produit_id = _produit_id AND depot_id = _depot_id;

  INSERT INTO public.stock_mouvements(
    produit_id, depot_id, type, quantite, quantite_entree, quantite_sortie, stock_resultant,
    motif, origine, user_id, user_nom
  ) VALUES (
    _produit_id, _depot_id, 'ajustement', v_delta, GREATEST(v_delta, 0), GREATEST(-v_delta, 0), _nouvelle_quantite,
    COALESCE(_motif, 'Ajustement manuel'), 'ajustement', auth.uid(), v_user_nom
  );
END; $$;

-- 3. Attribuer les accès aux dépôts aux admins/gestionnaires
INSERT INTO public.user_depots (user_id, depot_id, principal)
SELECT p.id, d.depot_id, false
FROM public.profiles p, public.depots d
WHERE EXISTS (SELECT 1 FROM public.rbac2_user_roles ur WHERE ur.user_id = p.id AND ur.role_code IN ('super_admin', 'gestionnaire_stock', 'directeur'))
ON CONFLICT (user_id, depot_id) DO NOTHING;
