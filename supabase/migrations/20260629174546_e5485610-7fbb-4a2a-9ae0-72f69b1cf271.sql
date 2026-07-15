
-- 1) Étend enregistrer_approvisionnement avec depot_id obligatoire
CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
 RETURNS achats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_achat public.achats%ROWTYPE;
  v_fournisseur_id uuid;
  v_fournisseur record;
  v_depot_id uuid;
  v_date date;
  v_lignes jsonb;
  v_ligne jsonb;
  v_montant numeric := 0;
  v_total_ligne numeric;
  v_libelle text;
  v_nom_user text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock',
             'responsable_magasinier','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour enregistrer un approvisionnement'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_fournisseur_id := NULLIF(_payload->>'fournisseur_id','')::uuid;
  IF v_fournisseur_id IS NULL THEN
    RAISE EXCEPTION 'Le fournisseur est obligatoire';
  END IF;
  SELECT * INTO v_fournisseur FROM public.fournisseurs WHERE fournisseur_id = v_fournisseur_id;
  IF v_fournisseur IS NULL THEN
    RAISE EXCEPTION 'Fournisseur introuvable';
  END IF;

  v_depot_id := NULLIF(_payload->>'depot_id','')::uuid;
  IF v_depot_id IS NULL THEN
    SELECT depot_id INTO v_depot_id FROM public.depots WHERE is_principal = true LIMIT 1;
  END IF;
  IF v_depot_id IS NULL THEN
    RAISE EXCEPTION 'Le dépôt de destination est obligatoire';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.depots WHERE depot_id = v_depot_id AND actif = true) THEN
    RAISE EXCEPTION 'Dépôt introuvable ou inactif';
  END IF;

  v_date := COALESCE((_payload->>'date_achat')::date, CURRENT_DATE);
  v_lignes := _payload->'lignes';

  IF v_lignes IS NULL OR jsonb_typeof(v_lignes) <> 'array' OR jsonb_array_length(v_lignes) = 0 THEN
    RAISE EXCEPTION 'Ajoutez au moins une ligne produit';
  END IF;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_lignes) LOOP
    IF COALESCE((v_ligne->>'quantite')::integer, 0) <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide pour la ligne "%"',
        COALESCE(v_ligne->>'designation','(produit)');
    END IF;
    IF COALESCE((v_ligne->>'prix_unitaire')::numeric, 0) < 0 THEN
      RAISE EXCEPTION 'Prix d''achat invalide pour la ligne "%"',
        COALESCE(v_ligne->>'designation','(produit)');
    END IF;
    v_montant := v_montant + ((v_ligne->>'quantite')::numeric * (v_ligne->>'prix_unitaire')::numeric);
  END LOOP;

  v_libelle := COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'libelle','')), ''),
                        'Approvisionnement ' || v_fournisseur.raison_sociale);
  v_nom_user := COALESCE(auth.jwt() -> 'user_metadata' ->> 'nom_complet',
                         auth.jwt() ->> 'email');

  INSERT INTO public.achats (
    fournisseur_id, libelle, montant, statut, date_achat,
    notes, reference_fournisseur, created_by, created_by_nom
  ) VALUES (
    v_fournisseur_id, v_libelle, v_montant, 'recu', v_date,
    NULLIF(BTRIM(COALESCE(_payload->>'notes','')),''),
    NULLIF(BTRIM(COALESCE(_payload->>'reference_fournisseur','')),''),
    auth.uid(), v_nom_user
  )
  RETURNING * INTO v_achat;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_lignes) LOOP
    v_total_ligne := (v_ligne->>'quantite')::numeric * (v_ligne->>'prix_unitaire')::numeric;

    INSERT INTO public.achat_lignes (
      achat_id, produit_id, reference_produit, designation,
      quantite, prix_unitaire, total_ligne
    ) VALUES (
      v_achat.achat_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      NULLIF(v_ligne->>'reference_produit',''),
      COALESCE(NULLIF(v_ligne->>'designation',''), 'Produit'),
      (v_ligne->>'quantite')::integer,
      (v_ligne->>'prix_unitaire')::numeric,
      v_total_ligne
    );

    IF NULLIF(v_ligne->>'produit_id','') IS NOT NULL THEN
      INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
      VALUES (
        (v_ligne->>'produit_id')::uuid,
        'entree',
        (v_ligne->>'quantite')::integer,
        'Approvisionnement ' || v_achat.reference,
        v_depot_id
      );

      UPDATE public.produits
         SET prix_achat = (v_ligne->>'prix_unitaire')::numeric,
             updated_at = now()
       WHERE produit_id = (v_ligne->>'produit_id')::uuid;
    END IF;
  END LOOP;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'create_approvisionnement', 'achats', v_achat.achat_id::text);

  RETURN v_achat;
END;
$function$;

-- 2) Ajustement direct du stock d'un produit dans un dépôt
CREATE OR REPLACE FUNCTION public.ajuster_stock_depot(
  _produit_id uuid,
  _depot_id uuid,
  _nouvelle_quantite integer,
  _motif text DEFAULT NULL
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_motif text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock',
             'responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour ajuster un stock'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF _nouvelle_quantite < 0 THEN
    RAISE EXCEPTION 'La quantité ne peut pas être négative';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.produits WHERE produit_id = _produit_id) THEN
    RAISE EXCEPTION 'Produit introuvable';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.depots WHERE depot_id = _depot_id) THEN
    RAISE EXCEPTION 'Dépôt introuvable';
  END IF;

  v_motif := COALESCE(NULLIF(BTRIM(_motif), ''), 'Ajustement manuel');

  INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
  VALUES (_produit_id, 'ajustement', _nouvelle_quantite, v_motif, _depot_id);

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'ajuster_stock_depot', 'stocks_depots',
            _produit_id::text || '/' || _depot_id::text);
END;
$function$;
