
-- 1. Extension table retours
ALTER TABLE public.retours
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS client_id uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS etablissement text,
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS total_quantite integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_produits integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_by_nom text;

-- Rendre les colonnes legacy mono-produit optionnelles
ALTER TABLE public.retours ALTER COLUMN quantite DROP NOT NULL;
ALTER TABLE public.retours ALTER COLUMN montant DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS retours_numero_uidx ON public.retours(numero) WHERE numero IS NOT NULL;

-- 2. Table retour_lignes
CREATE TABLE IF NOT EXISTS public.retour_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retour_id uuid NOT NULL REFERENCES public.retours(retour_id) ON DELETE CASCADE,
  produit_id uuid REFERENCES public.produits(produit_id) ON DELETE SET NULL,
  reference_produit text,
  designation text NOT NULL,
  quantite integer NOT NULL CHECK (quantite > 0),
  motif text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.retour_lignes TO authenticated;
GRANT ALL ON public.retour_lignes TO service_role;

ALTER TABLE public.retour_lignes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff read retour_lignes" ON public.retour_lignes;
CREATE POLICY "Staff read retour_lignes" ON public.retour_lignes
  FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
DROP POLICY IF EXISTS "Staff write retour_lignes" ON public.retour_lignes;
CREATE POLICY "Staff write retour_lignes" ON public.retour_lignes
  FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

CREATE INDEX IF NOT EXISTS retour_lignes_retour_idx ON public.retour_lignes(retour_id);

-- 3. RPC creer_retour
CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
RETURNS public.retours
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ret public.retours%ROWTYPE;
  v_numero text;
  v_seq integer;
  v_date date;
  v_client_id uuid;
  v_client record;
  v_depot uuid;
  v_lignes jsonb;
  v_ligne jsonb;
  v_total_qte integer := 0;
  v_nb integer := 0;
  v_etablissement text;
  v_nom_user text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE='insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','directeur_commercial',
             'gestionnaire_stock','responsable_magasinier','secretariat']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour enregistrer un retour'
      USING ERRCODE='insufficient_privilege';
  END IF;

  v_date := COALESCE((_payload->>'date_retour')::date, CURRENT_DATE);
  v_client_id := NULLIF(_payload->>'client_id','')::uuid;
  v_lignes := _payload->'lignes';

  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Sélectionnez un client';
  END IF;
  SELECT * INTO v_client FROM public.clients WHERE client_id = v_client_id;
  IF v_client IS NULL THEN
    RAISE EXCEPTION 'Client introuvable';
  END IF;

  IF v_lignes IS NULL OR jsonb_typeof(v_lignes) <> 'array' OR jsonb_array_length(v_lignes) = 0 THEN
    RAISE EXCEPTION 'Ajoutez au moins une ligne produit';
  END IF;

  v_depot := NULLIF(_payload->>'depot_id','')::uuid;
  IF v_depot IS NULL THEN
    SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal = true LIMIT 1;
  END IF;

  v_etablissement := COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'etablissement','')),''), v_client.nom);

  SELECT COUNT(*) + 1 INTO v_seq FROM public.retours WHERE date_retour = v_date;
  v_numero := 'RET-' || to_char(v_date,'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');
  v_nom_user := COALESCE(auth.jwt() -> 'user_metadata' ->> 'nom_complet', auth.jwt() ->> 'email');

  INSERT INTO public.retours (
    numero, date_retour, client_id, client_nom, etablissement,
    representant_nom, telephone, ville, adresse,
    depot_id, observations, notes, statut,
    created_by, created_by_nom
  ) VALUES (
    v_numero, v_date, v_client_id, v_etablissement, v_etablissement,
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'representant_nom','')),''), v_client.representant),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'telephone','')),''), v_client.telephone),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'ville','')),''), v_client.ville),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'adresse','')),''), v_client.adresse),
    v_depot,
    NULLIF(BTRIM(COALESCE(_payload->>'observations','')),''),
    NULLIF(BTRIM(COALESCE(_payload->>'notes','')),''),
    'accepte',
    auth.uid(), v_nom_user
  ) RETURNING * INTO v_ret;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_lignes) LOOP
    IF COALESCE((v_ligne->>'quantite')::integer, 0) <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide pour la ligne "%"',
        COALESCE(v_ligne->>'designation','(produit)');
    END IF;

    INSERT INTO public.retour_lignes (
      retour_id, produit_id, reference_produit, designation, quantite, motif
    ) VALUES (
      v_ret.retour_id,
      NULLIF(v_ligne->>'produit_id','')::uuid,
      NULLIF(v_ligne->>'reference_produit',''),
      COALESCE(NULLIF(v_ligne->>'designation',''), 'Produit'),
      (v_ligne->>'quantite')::integer,
      NULLIF(BTRIM(COALESCE(v_ligne->>'motif','')),'')
    );

    IF NULLIF(v_ligne->>'produit_id','') IS NOT NULL THEN
      INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
      VALUES (
        (v_ligne->>'produit_id')::uuid,
        'entree',
        (v_ligne->>'quantite')::integer,
        'Retour ' || v_numero,
        v_depot
      );
    END IF;

    v_total_qte := v_total_qte + (v_ligne->>'quantite')::integer;
    v_nb := v_nb + 1;
  END LOOP;

  UPDATE public.retours
     SET total_quantite = v_total_qte, nb_produits = v_nb, updated_at = now()
   WHERE retour_id = v_ret.retour_id
   RETURNING * INTO v_ret;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'create_retour', 'retours', v_ret.retour_id::text);

  RETURN v_ret;
END;
$$;

-- 4. RPC annuler_retour
CREATE OR REPLACE FUNCTION public.annuler_retour(_retour_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ret public.retours%ROWTYPE;
  v_ligne record;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','directeur_commercial',
             'gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  SELECT * INTO v_ret FROM public.retours WHERE retour_id = _retour_id FOR UPDATE;
  IF v_ret IS NULL THEN RAISE EXCEPTION 'Retour introuvable'; END IF;
  IF v_ret.statut = 'annule' THEN RETURN; END IF;

  FOR v_ligne IN SELECT produit_id, quantite FROM public.retour_lignes WHERE retour_id = _retour_id
  LOOP
    IF v_ligne.produit_id IS NOT NULL THEN
      INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
      VALUES (v_ligne.produit_id, 'sortie', v_ligne.quantite,
              'Annulation retour ' || COALESCE(v_ret.numero, v_ret.reference),
              v_ret.depot_id);
    END IF;
  END LOOP;

  UPDATE public.retours SET statut = 'annule', updated_at = now()
    WHERE retour_id = _retour_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'cancel_retour', 'retours', _retour_id::text);
END;
$$;
