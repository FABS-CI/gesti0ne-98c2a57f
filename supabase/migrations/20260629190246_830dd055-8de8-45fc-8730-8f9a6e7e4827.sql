-- ============================================================
-- PHASE 1 : Refonte module Commandes - Schéma & RPC
-- ============================================================

-- 1. Extension de la table commande_lignes
ALTER TABLE public.commande_lignes
  ADD COLUMN IF NOT EXISTS reference_produit text,
  ADD COLUMN IF NOT EXISTS remise_pct numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_remise numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ht_ligne numeric NOT NULL DEFAULT 0;

-- 2. Extension de la table commandes
ALTER TABLE public.commandes
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS etablissement text,
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS nb_produits integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_quantite integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ht_brut numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_remises_lignes numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ht_net numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remise_globale_pct numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remise_globale_montant numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS taux_tva numeric NOT NULL DEFAULT 18,
  ADD COLUMN IF NOT EXISTS montant_tva numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS montant_ttc numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_a_payer numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS commercial_id uuid,
  ADD COLUMN IF NOT EXISTS commercial_nom text,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_by_nom text;

-- 3. Helper : génération du numéro de commande
CREATE OR REPLACE FUNCTION public._next_commande_numero(_date date)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_seq int;
BEGIN
  SELECT COUNT(*)+1 INTO v_seq FROM public.commandes WHERE date_commande = _date;
  RETURN 'CMD-' || to_char(_date,'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');
END $$;

-- 4. Helper : recalcul totaux d'une commande à partir des lignes + remise globale
CREATE OR REPLACE FUNCTION public._recalc_commande_totaux(_commande_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_brut numeric := 0;
  v_remises_lignes numeric := 0;
  v_ht_net numeric := 0;
  v_qte int := 0;
  v_nb int := 0;
  v_rg_pct numeric;
  v_rg_montant numeric;
  v_taux_tva numeric;
  v_tva numeric;
  v_ttc numeric;
BEGIN
  SELECT
    COALESCE(SUM(quantite * prix_unitaire), 0),
    COALESCE(SUM(montant_remise), 0),
    COALESCE(SUM(total_ht_ligne), 0),
    COALESCE(SUM(quantite), 0),
    COUNT(*)
  INTO v_brut, v_remises_lignes, v_ht_net, v_qte, v_nb
  FROM public.commande_lignes WHERE commande_id = _commande_id;

  SELECT COALESCE(remise_globale_pct,0), COALESCE(taux_tva,18)
    INTO v_rg_pct, v_taux_tva
  FROM public.commandes WHERE commande_id = _commande_id;

  v_rg_montant := round(v_ht_net * v_rg_pct / 100, 2);
  v_tva := round((v_ht_net - v_rg_montant) * v_taux_tva / 100, 2);
  v_ttc := (v_ht_net - v_rg_montant) + v_tva;

  UPDATE public.commandes SET
    total_ht_brut = v_brut,
    total_remises_lignes = v_remises_lignes,
    total_ht_net = v_ht_net,
    remise_globale_montant = v_rg_montant,
    montant_tva = v_tva,
    montant_ttc = v_ttc,
    net_a_payer = v_ttc,
    montant_total = v_ttc,
    nb_produits = v_nb,
    total_quantite = v_qte,
    updated_at = now()
  WHERE commande_id = _commande_id;
END $$;

-- 5. RPC : créer une commande
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
RETURNS commandes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cmd public.commandes%ROWTYPE;
  v_date date;
  v_client_id uuid;
  v_client record;
  v_lignes jsonb;
  v_ligne jsonb;
  v_etablissement text;
  v_nom_user text;
  v_numero text;
  v_qte numeric;
  v_pu numeric;
  v_rem_pct numeric;
  v_brut numeric;
  v_montant_rem numeric;
  v_total_ligne numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE='insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','directeur_commercial','secretariat','assistante']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour créer une commande'
      USING ERRCODE='insufficient_privilege';
  END IF;

  v_date := COALESCE((_payload->>'date_commande')::date, CURRENT_DATE);
  v_client_id := NULLIF(_payload->>'client_id','')::uuid;
  v_lignes := _payload->'lignes';

  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Sélectionnez un client';
  END IF;
  SELECT * INTO v_client FROM public.clients WHERE client_id = v_client_id;
  IF v_client IS NULL THEN RAISE EXCEPTION 'Client introuvable'; END IF;

  IF v_lignes IS NULL OR jsonb_typeof(v_lignes) <> 'array' OR jsonb_array_length(v_lignes) = 0 THEN
    RAISE EXCEPTION 'Ajoutez au moins une ligne produit';
  END IF;

  v_etablissement := COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'etablissement','')),''), v_client.nom);
  v_numero := public._next_commande_numero(v_date);
  v_nom_user := COALESCE(auth.jwt() -> 'user_metadata' ->> 'nom_complet', auth.jwt() ->> 'email');

  INSERT INTO public.commandes (
    reference, numero, client_id, client_nom, etablissement,
    representant_nom, telephone, ville, adresse,
    date_commande, statut, observations, notes,
    remise_globale_pct, taux_tva,
    commercial_id, commercial_nom, created_by, created_by_nom,
    montant_total
  ) VALUES (
    v_numero, v_numero, v_client_id, v_etablissement, v_etablissement,
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'representant_nom','')),''), v_client.representant),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'telephone','')),''), v_client.telephone),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'ville','')),''), v_client.ville),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'adresse','')),''), v_client.adresse),
    v_date, 'brouillon',
    NULLIF(BTRIM(COALESCE(_payload->>'observations','')),''),
    NULLIF(BTRIM(COALESCE(_payload->>'notes','')),''),
    COALESCE((_payload->>'remise_globale_pct')::numeric, 0),
    COALESCE((_payload->>'taux_tva')::numeric, 18),
    auth.uid(), v_nom_user, auth.uid(), v_nom_user,
    0
  ) RETURNING * INTO v_cmd;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_lignes) LOOP
    v_qte := COALESCE((v_ligne->>'quantite')::numeric, 0);
    v_pu := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
    v_rem_pct := COALESCE((v_ligne->>'remise_pct')::numeric, 0);

    IF v_qte <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide pour la ligne "%"', COALESCE(v_ligne->>'designation','(produit)');
    END IF;
    IF v_pu < 0 THEN
      RAISE EXCEPTION 'Prix unitaire invalide pour la ligne "%"', COALESCE(v_ligne->>'designation','(produit)');
    END IF;
    IF v_rem_pct < 0 OR v_rem_pct > 100 THEN
      RAISE EXCEPTION 'Remise invalide (0-100) pour la ligne "%"', COALESCE(v_ligne->>'designation','(produit)');
    END IF;

    v_brut := v_qte * v_pu;
    v_montant_rem := round(v_brut * v_rem_pct / 100, 2);
    v_total_ligne := v_brut - v_montant_rem;

    INSERT INTO public.commande_lignes (
      commande_id, produit_id, reference_produit, designation,
      quantite, prix_unitaire, remise_pct, montant_remise, total_ligne, total_ht_ligne
    ) VALUES (
      v_cmd.commande_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      NULLIF(v_ligne->>'reference_produit',''),
      COALESCE(NULLIF(v_ligne->>'designation',''), 'Produit'),
      v_qte::int, v_pu, v_rem_pct, v_montant_rem, v_total_ligne, v_total_ligne
    );
  END LOOP;

  PERFORM public._recalc_commande_totaux(v_cmd.commande_id);
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = v_cmd.commande_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'create_commande', 'commandes', v_cmd.commande_id::text);

  RETURN v_cmd;
END;
$$;

-- 6. RPC : modifier une commande (brouillon ou en_attente_validation uniquement)
CREATE OR REPLACE FUNCTION public.modifier_commande(_commande_id uuid, _payload jsonb)
RETURNS commandes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cmd public.commandes%ROWTYPE;
  v_old jsonb;
  v_lignes jsonb;
  v_ligne jsonb;
  v_qte numeric; v_pu numeric; v_rem_pct numeric;
  v_brut numeric; v_montant_rem numeric; v_total_ligne numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE='insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','directeur_commercial','secretariat','assistante']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;
  IF v_cmd.statut NOT IN ('brouillon','en_attente_validation') THEN
    RAISE EXCEPTION 'Modification interdite: commande au statut %', v_cmd.statut;
  END IF;

  v_old := to_jsonb(v_cmd);
  v_lignes := _payload->'lignes';

  UPDATE public.commandes SET
    representant_nom = COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'representant_nom','')),''), representant_nom),
    telephone = COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'telephone','')),''), telephone),
    ville = COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'ville','')),''), ville),
    adresse = COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'adresse','')),''), adresse),
    observations = COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'observations','')),''), observations),
    remise_globale_pct = COALESCE((_payload->>'remise_globale_pct')::numeric, remise_globale_pct),
    taux_tva = COALESCE((_payload->>'taux_tva')::numeric, taux_tva),
    updated_at = now()
  WHERE commande_id = _commande_id;

  IF v_lignes IS NOT NULL AND jsonb_typeof(v_lignes) = 'array' THEN
    IF jsonb_array_length(v_lignes) = 0 THEN
      RAISE EXCEPTION 'Au moins une ligne produit est requise';
    END IF;

    DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;

    FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_lignes) LOOP
      v_qte := COALESCE((v_ligne->>'quantite')::numeric, 0);
      v_pu := COALESCE((v_ligne->>'prix_unitaire')::numeric, 0);
      v_rem_pct := COALESCE((v_ligne->>'remise_pct')::numeric, 0);

      IF v_qte <= 0 THEN RAISE EXCEPTION 'Quantité invalide'; END IF;
      IF v_pu < 0 THEN RAISE EXCEPTION 'Prix invalide'; END IF;
      IF v_rem_pct < 0 OR v_rem_pct > 100 THEN RAISE EXCEPTION 'Remise invalide (0-100)'; END IF;

      v_brut := v_qte * v_pu;
      v_montant_rem := round(v_brut * v_rem_pct / 100, 2);
      v_total_ligne := v_brut - v_montant_rem;

      INSERT INTO public.commande_lignes (
        commande_id, produit_id, reference_produit, designation,
        quantite, prix_unitaire, remise_pct, montant_remise, total_ligne, total_ht_ligne
      ) VALUES (
        _commande_id,
        NULLIF(v_ligne->>'produit_id','')::uuid,
        NULLIF(v_ligne->>'reference_produit',''),
        COALESCE(NULLIF(v_ligne->>'designation',''), 'Produit'),
        v_qte::int, v_pu, v_rem_pct, v_montant_rem, v_total_ligne, v_total_ligne
      );
    END LOOP;
  END IF;

  PERFORM public._recalc_commande_totaux(_commande_id);
  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_values, new_values)
    VALUES (auth.uid(), 'update_commande', 'commandes', _commande_id::text, v_old, to_jsonb(v_cmd));

  RETURN v_cmd;
END;
$$;

-- 7. RPC : soumettre commande pour validation (brouillon -> en_attente_validation)
CREATE OR REPLACE FUNCTION public.soumettre_commande(_commande_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','directeur_commercial','secretariat','assistante']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  UPDATE public.commandes SET statut = 'en_attente_validation', updated_at = now()
    WHERE commande_id = _commande_id AND statut = 'brouillon';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Commande introuvable ou pas au statut brouillon';
  END IF;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'submit_commande', 'commandes', _commande_id::text);
END $$;

-- 8. RPC : générer manuellement la proforma d'une commande
CREATE OR REPLACE FUNCTION public.generer_proforma_commande(_commande_id uuid)
RETURNS proformas
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cmd public.commandes%ROWTYPE;
  v_pro public.proformas%ROWTYPE;
  v_ref text;
  v_ligne record;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','directeur_commercial','secretariat','assistante']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF v_cmd IS NULL THEN RAISE EXCEPTION 'Commande introuvable'; END IF;

  SELECT * INTO v_pro FROM public.proformas WHERE commande_id = _commande_id LIMIT 1;
  IF v_pro.proforma_id IS NOT NULL THEN RETURN v_pro; END IF;

  v_ref := 'PRO-' || to_char(now(),'YYYYMMDD-HH24MISS') || '-' || substr(_commande_id::text,1,4);

  INSERT INTO public.proformas (
    reference, client_id, client_nom, date_proforma, date_validite,
    montant_total, statut, notes, commande_id
  ) VALUES (
    v_ref, v_cmd.client_id, v_cmd.client_nom, v_cmd.date_commande,
    (v_cmd.date_commande + INTERVAL '30 days')::date,
    v_cmd.net_a_payer, 'en_attente',
    'Proforma générée pour la commande ' || v_cmd.reference,
    _commande_id
  ) RETURNING * INTO v_pro;

  FOR v_ligne IN SELECT * FROM public.commande_lignes WHERE commande_id = _commande_id LOOP
    INSERT INTO public.proforma_lignes (
      proforma_id, produit_id, designation, quantite, prix_unitaire, total_ligne
    ) VALUES (
      v_pro.proforma_id, v_ligne.produit_id, v_ligne.designation,
      v_ligne.quantite, v_ligne.prix_unitaire, v_ligne.total_ht_ligne
    );
  END LOOP;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'generate_proforma', 'proformas', v_pro.proforma_id::text);

  RETURN v_pro;
END $$;