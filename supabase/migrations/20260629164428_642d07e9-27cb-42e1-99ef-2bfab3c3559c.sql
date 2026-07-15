
-- 1. Colonnes additionnelles sur achats
ALTER TABLE public.achats
  ADD COLUMN IF NOT EXISTS reference_fournisseur text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by_nom text;

-- 2. Table achat_lignes
CREATE TABLE IF NOT EXISTS public.achat_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  achat_id uuid NOT NULL REFERENCES public.achats(achat_id) ON DELETE CASCADE,
  produit_id uuid REFERENCES public.produits(produit_id) ON DELETE SET NULL,
  reference_produit text,
  designation text NOT NULL,
  quantite integer NOT NULL CHECK (quantite > 0),
  prix_unitaire numeric NOT NULL DEFAULT 0 CHECK (prix_unitaire >= 0),
  total_ligne numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_achat_lignes_achat_id ON public.achat_lignes(achat_id);
CREATE INDEX IF NOT EXISTS idx_achat_lignes_produit_id ON public.achat_lignes(produit_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.achat_lignes TO authenticated;
GRANT ALL ON public.achat_lignes TO service_role;

ALTER TABLE public.achat_lignes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff view achat_lignes" ON public.achat_lignes
  FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert achat_lignes" ON public.achat_lignes
  FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update achat_lignes" ON public.achat_lignes
  FOR UPDATE TO authenticated
  USING (public.is_staff(auth.uid()))
  WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete achat_lignes" ON public.achat_lignes
  FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 3. RPC enregistrer_approvisionnement
CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
RETURNS public.achats
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_achat public.achats%ROWTYPE;
  v_fournisseur_id uuid;
  v_fournisseur record;
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

  v_date := COALESCE((_payload->>'date_achat')::date, CURRENT_DATE);
  v_lignes := _payload->'lignes';

  IF v_lignes IS NULL OR jsonb_typeof(v_lignes) <> 'array' OR jsonb_array_length(v_lignes) = 0 THEN
    RAISE EXCEPTION 'Ajoutez au moins une ligne produit';
  END IF;

  -- Calcul du montant total
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

  -- Création de l'approvisionnement directement au statut 'recu'
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

  -- Insertion des lignes + mouvements de stock
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
      INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif)
      VALUES (
        (v_ligne->>'produit_id')::uuid,
        'entree',
        (v_ligne->>'quantite')::integer,
        'Approvisionnement ' || v_achat.reference
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
$$;

REVOKE ALL ON FUNCTION public.enregistrer_approvisionnement(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enregistrer_approvisionnement(jsonb) TO authenticated;
