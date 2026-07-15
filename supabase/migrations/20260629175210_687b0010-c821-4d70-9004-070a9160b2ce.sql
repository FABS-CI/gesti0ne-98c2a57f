
-- 1) Drop legacy inventaires (no data)
DROP TABLE IF EXISTS public.inventaires CASCADE;

-- 2) Nouvelle table inventaires (header)
CREATE TABLE public.inventaires (
  inventaire_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero text NOT NULL UNIQUE,
  type_inventaire text NOT NULL CHECK (type_inventaire IN ('theorique','physique','global','par_depot')),
  depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  categorie_id uuid REFERENCES public.categories_produits(categorie_id) ON DELETE SET NULL,
  date_inventaire date NOT NULL DEFAULT CURRENT_DATE,
  statut text NOT NULL DEFAULT 'brouillon' CHECK (statut IN ('brouillon','valide','regularise','annule')),
  nb_produits integer NOT NULL DEFAULT 0,
  nb_ecarts integer NOT NULL DEFAULT 0,
  valeur_totale numeric NOT NULL DEFAULT 0,
  observations text,
  created_by uuid REFERENCES auth.users(id),
  created_by_nom text,
  validated_at timestamptz,
  validated_by uuid REFERENCES auth.users(id),
  regularized_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventaires TO authenticated;
GRANT ALL ON public.inventaires TO service_role;
ALTER TABLE public.inventaires ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventaires_staff_read" ON public.inventaires FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));
CREATE POLICY "inventaires_staff_write" ON public.inventaires FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "inventaires_staff_update" ON public.inventaires FOR UPDATE TO authenticated
  USING (public.is_staff(auth.uid()));
CREATE POLICY "inventaires_staff_delete" ON public.inventaires FOR DELETE TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::app_role[]));

CREATE TRIGGER update_inventaires_updated_at BEFORE UPDATE ON public.inventaires
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX idx_inventaires_date ON public.inventaires(date_inventaire DESC);
CREATE INDEX idx_inventaires_depot ON public.inventaires(depot_id);
CREATE INDEX idx_inventaires_statut ON public.inventaires(statut);

-- 3) inventaire_lignes
CREATE TABLE public.inventaire_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventaire_id uuid NOT NULL REFERENCES public.inventaires(inventaire_id) ON DELETE CASCADE,
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id) ON DELETE RESTRICT,
  reference_produit text,
  designation text NOT NULL,
  stock_theorique integer NOT NULL DEFAULT 0,
  quantite_comptee integer NOT NULL DEFAULT 0,
  ecart integer NOT NULL DEFAULT 0,
  valeur_unitaire numeric NOT NULL DEFAULT 0,
  valeur_ecart numeric NOT NULL DEFAULT 0,
  observation text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventaire_lignes TO authenticated;
GRANT ALL ON public.inventaire_lignes TO service_role;
ALTER TABLE public.inventaire_lignes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventaire_lignes_staff_all" ON public.inventaire_lignes FOR ALL TO authenticated
  USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

CREATE INDEX idx_inventaire_lignes_inventaire ON public.inventaire_lignes(inventaire_id);
CREATE INDEX idx_inventaire_lignes_produit ON public.inventaire_lignes(produit_id);

-- 4) Generate numero helper
CREATE OR REPLACE FUNCTION public._next_inventaire_numero(_date date)
 RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_seq int;
BEGIN
  SELECT COUNT(*)+1 INTO v_seq FROM public.inventaires WHERE date_inventaire = _date;
  RETURN 'INV-' || to_char(_date,'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');
END $$;

-- 5) creer_inventaire_physique : crée brouillon + lignes snapshot
CREATE OR REPLACE FUNCTION public.creer_inventaire_physique(_payload jsonb)
 RETURNS inventaires
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_inv public.inventaires%ROWTYPE;
  v_depot_id uuid;
  v_categorie_id uuid;
  v_date date;
  v_type text;
  v_nb int := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE='insufficient_privilege';
  END IF;
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  v_date := COALESCE((_payload->>'date_inventaire')::date, CURRENT_DATE);
  v_depot_id := NULLIF(_payload->>'depot_id','')::uuid;
  v_categorie_id := NULLIF(_payload->>'categorie_id','')::uuid;
  v_type := COALESCE(NULLIF(_payload->>'type_inventaire',''),'physique');

  IF v_type = 'physique' AND v_depot_id IS NULL THEN
    RAISE EXCEPTION 'Le dépôt est obligatoire pour un inventaire physique';
  END IF;

  INSERT INTO public.inventaires (
    numero, type_inventaire, depot_id, categorie_id, date_inventaire, statut,
    observations, created_by, created_by_nom
  ) VALUES (
    public._next_inventaire_numero(v_date), v_type, v_depot_id, v_categorie_id, v_date, 'brouillon',
    NULLIF(BTRIM(COALESCE(_payload->>'observations','')),''),
    auth.uid(),
    COALESCE(auth.jwt() -> 'user_metadata' ->> 'nom_complet', auth.jwt() ->> 'email')
  ) RETURNING * INTO v_inv;

  -- Snapshot lignes : tous produits actifs du dépôt (filtrés par catégorie si fournie)
  INSERT INTO public.inventaire_lignes (
    inventaire_id, produit_id, reference_produit, designation,
    stock_theorique, quantite_comptee, ecart, valeur_unitaire
  )
  SELECT
    v_inv.inventaire_id, p.produit_id, p.reference, p.titre,
    COALESCE(sd.quantite, 0), 0, -COALESCE(sd.quantite,0), COALESCE(p.prix_achat,0)
  FROM public.produits p
  LEFT JOIN public.stocks_depots sd
    ON sd.produit_id = p.produit_id AND sd.depot_id = v_depot_id
  WHERE p.actif = true
    AND (v_categorie_id IS NULL OR p.categorie_id = v_categorie_id)
    AND (v_depot_id IS NULL OR sd.quantite IS NOT NULL OR true);

  SELECT COUNT(*) INTO v_nb FROM public.inventaire_lignes WHERE inventaire_id = v_inv.inventaire_id;
  UPDATE public.inventaires SET nb_produits = v_nb WHERE inventaire_id = v_inv.inventaire_id
    RETURNING * INTO v_inv;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'create_inventaire_physique', 'inventaires', v_inv.inventaire_id::text);

  RETURN v_inv;
END $$;

-- 6) valider_inventaire_physique : applique les comptages et fige
CREATE OR REPLACE FUNCTION public.valider_inventaire_physique(_inventaire_id uuid, _lignes jsonb)
 RETURNS inventaires
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_inv public.inventaires%ROWTYPE;
  v_ligne jsonb;
  v_ecart int;
  v_nb_ecarts int := 0;
  v_valeur numeric := 0;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  SELECT * INTO v_inv FROM public.inventaires WHERE inventaire_id = _inventaire_id FOR UPDATE;
  IF v_inv IS NULL THEN RAISE EXCEPTION 'Inventaire introuvable'; END IF;
  IF v_inv.statut <> 'brouillon' THEN
    RAISE EXCEPTION 'Inventaire déjà validé (%)', v_inv.statut;
  END IF;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(_lignes) LOOP
    UPDATE public.inventaire_lignes
       SET quantite_comptee = COALESCE((v_ligne->>'quantite_comptee')::int, 0),
           ecart = COALESCE((v_ligne->>'quantite_comptee')::int, 0) - stock_theorique,
           valeur_ecart = (COALESCE((v_ligne->>'quantite_comptee')::int, 0) - stock_theorique) * valeur_unitaire,
           observation = NULLIF(BTRIM(COALESCE(v_ligne->>'observation','')),'')
     WHERE ligne_id = (v_ligne->>'ligne_id')::uuid
       AND inventaire_id = _inventaire_id;
  END LOOP;

  SELECT
    COUNT(*) FILTER (WHERE ecart <> 0),
    COALESCE(SUM(quantite_comptee * valeur_unitaire), 0)
  INTO v_nb_ecarts, v_valeur
  FROM public.inventaire_lignes WHERE inventaire_id = _inventaire_id;

  UPDATE public.inventaires
     SET statut = 'valide', nb_ecarts = v_nb_ecarts, valeur_totale = v_valeur,
         validated_at = now(), validated_by = auth.uid(), updated_at = now()
   WHERE inventaire_id = _inventaire_id
   RETURNING * INTO v_inv;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'valider_inventaire_physique', 'inventaires', _inventaire_id::text);

  RETURN v_inv;
END $$;

-- 7) regulariser_inventaire : applique les écarts via stock_mouvements
CREATE OR REPLACE FUNCTION public.regulariser_inventaire(_inventaire_id uuid)
 RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_inv public.inventaires%ROWTYPE;
  v_ligne record;
  v_nouvelle int;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  SELECT * INTO v_inv FROM public.inventaires WHERE inventaire_id = _inventaire_id FOR UPDATE;
  IF v_inv IS NULL THEN RAISE EXCEPTION 'Inventaire introuvable'; END IF;
  IF v_inv.statut <> 'valide' THEN
    RAISE EXCEPTION 'Seul un inventaire validé peut être régularisé (statut actuel: %)', v_inv.statut;
  END IF;
  IF v_inv.depot_id IS NULL THEN
    RAISE EXCEPTION 'Inventaire sans dépôt : régularisation impossible';
  END IF;

  FOR v_ligne IN
    SELECT * FROM public.inventaire_lignes
    WHERE inventaire_id = _inventaire_id AND ecart <> 0
  LOOP
    v_nouvelle := v_ligne.stock_theorique + v_ligne.ecart;
    IF v_nouvelle < 0 THEN v_nouvelle := 0; END IF;
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
    VALUES (v_ligne.produit_id, 'ajustement', v_nouvelle,
            'Régularisation inventaire ' || v_inv.numero, v_inv.depot_id);
  END LOOP;

  UPDATE public.inventaires
     SET statut = 'regularise', regularized_at = now(), updated_at = now()
   WHERE inventaire_id = _inventaire_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'regulariser_inventaire', 'inventaires', _inventaire_id::text);
END $$;

-- 8) annuler_inventaire (brouillon uniquement)
CREATE OR REPLACE FUNCTION public.annuler_inventaire(_inventaire_id uuid)
 RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;
  UPDATE public.inventaires SET statut = 'annule', updated_at = now()
    WHERE inventaire_id = _inventaire_id AND statut = 'brouillon';
  IF NOT FOUND THEN RAISE EXCEPTION 'Inventaire introuvable ou déjà traité'; END IF;
END $$;
