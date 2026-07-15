
-- 1. Drop legacy specimen objects (cascade clears RPCs, triggers, policies)
DROP FUNCTION IF EXISTS public.creer_et_valider_specimen_avec_lignes(date,text,text,uuid,text,text,text,text,text,text,text,jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.creer_specimen_avec_lignes(date,text,text,uuid,text,text,text,text,text,text,text,jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.valider_specimen(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.annuler_specimen(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.refresh_specimen_totaux(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.trg_specimen_lignes_totaux() CASCADE;
DROP FUNCTION IF EXISTS public.set_specimen_reference() CASCADE;
DROP FUNCTION IF EXISTS public.guard_specimen_status() CASCADE;
DROP FUNCTION IF EXISTS public.guard_specimen_delete() CASCADE;
DROP TABLE IF EXISTS public.specimen_lignes CASCADE;
DROP TABLE IF EXISTS public.specimens CASCADE;

-- 2. Tables
CREATE TABLE public.specimens (
  specimen_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero text UNIQUE NOT NULL,
  date_envoi date NOT NULL DEFAULT CURRENT_DATE,
  client_id uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  etablissement text NOT NULL,
  representant_nom text,
  telephone text,
  ville text,
  adresse text,
  donneur_nom text NOT NULL,
  motif text,
  observations text,
  statut text NOT NULL DEFAULT 'enregistre' CHECK (statut IN ('enregistre','annule')),
  gestionnaire_id uuid,
  gestionnaire_nom text,
  total_quantite integer NOT NULL DEFAULT 0,
  nb_produits integer NOT NULL DEFAULT 0,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.specimen_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  specimen_id uuid NOT NULL REFERENCES public.specimens(specimen_id) ON DELETE CASCADE,
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id),
  reference_produit text,
  designation text NOT NULL,
  quantite integer NOT NULL CHECK (quantite > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_specimens_date ON public.specimens(date_envoi DESC);
CREATE INDEX idx_specimens_client ON public.specimens(client_id);
CREATE INDEX idx_specimen_lignes_specimen ON public.specimen_lignes(specimen_id);
CREATE INDEX idx_specimen_lignes_produit ON public.specimen_lignes(produit_id);

-- 3. GRANTS
GRANT SELECT ON public.specimens TO authenticated;
GRANT ALL ON public.specimens TO service_role;
GRANT SELECT ON public.specimen_lignes TO authenticated;
GRANT ALL ON public.specimen_lignes TO service_role;

-- 4. RLS
ALTER TABLE public.specimens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specimen_lignes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can read specimens"
  ON public.specimens FOR SELECT
  TO authenticated
  USING (public.is_staff(auth.uid()));

CREATE POLICY "Staff can read specimen_lignes"
  ON public.specimen_lignes FOR SELECT
  TO authenticated
  USING (public.is_staff(auth.uid()));

-- 5. updated_at trigger
CREATE TRIGGER trg_specimens_updated_at
  BEFORE UPDATE ON public.specimens
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 6. RPC: create specimen (atomic, decrements stock via stock_mouvements)
CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
RETURNS public.specimens
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spec public.specimens%ROWTYPE;
  v_numero text;
  v_seq integer;
  v_date date;
  v_client_id uuid;
  v_client record;
  v_ligne jsonb;
  v_lignes jsonb;
  v_stock integer;
  v_total_qte integer := 0;
  v_nb integer := 0;
  v_etablissement text;
  v_donneur text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE='insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour enregistrer un spécimen'
      USING ERRCODE='insufficient_privilege';
  END IF;

  v_date := COALESCE((_payload->>'date_envoi')::date, CURRENT_DATE);
  v_client_id := NULLIF(_payload->>'client_id','')::uuid;
  v_donneur := NULLIF(BTRIM(COALESCE(_payload->>'donneur_nom','')), '');
  v_lignes := _payload->'lignes';

  IF v_donneur IS NULL THEN
    RAISE EXCEPTION 'Le nom du donneur des spécimens est obligatoire';
  END IF;

  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Sélectionnez un client (établissement bénéficiaire)';
  END IF;

  SELECT * INTO v_client FROM public.clients WHERE client_id = v_client_id;
  IF v_client IS NULL THEN
    RAISE EXCEPTION 'Client introuvable';
  END IF;

  v_etablissement := COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'etablissement','')),''), v_client.nom);

  IF v_lignes IS NULL OR jsonb_typeof(v_lignes) <> 'array' OR jsonb_array_length(v_lignes) = 0 THEN
    RAISE EXCEPTION 'Ajoutez au moins une ligne produit';
  END IF;

  -- Generate numero
  SELECT COUNT(*) + 1 INTO v_seq FROM public.specimens WHERE date_envoi = v_date;
  v_numero := 'SPC-' || to_char(v_date,'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');

  -- Insert specimen header
  INSERT INTO public.specimens (
    numero, date_envoi, client_id, etablissement,
    representant_nom, telephone, ville, adresse,
    donneur_nom, motif, observations, statut,
    gestionnaire_id, gestionnaire_nom, created_by
  )
  VALUES (
    v_numero, v_date, v_client_id, v_etablissement,
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'representant_nom','')),''), v_client.representant),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'telephone','')),''), v_client.telephone),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'ville','')),''), v_client.ville),
    COALESCE(NULLIF(BTRIM(COALESCE(_payload->>'adresse','')),''), v_client.adresse),
    v_donneur,
    NULLIF(BTRIM(COALESCE(_payload->>'motif','')),''),
    NULLIF(BTRIM(COALESCE(_payload->>'observations','')),''),
    'enregistre',
    auth.uid(),
    COALESCE(auth.jwt() -> 'user_metadata' ->> 'nom_complet', auth.jwt() ->> 'email'),
    auth.uid()
  )
  RETURNING * INTO v_spec;

  -- Insert lignes + stock check + stock mouvements
  FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_lignes)
  LOOP
    IF COALESCE((v_ligne->>'quantite')::integer, 0) <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide pour la ligne %', COALESCE(v_ligne->>'designation','(produit)');
    END IF;

    SELECT COALESCE(stock,0) INTO v_stock FROM public.produits
      WHERE produit_id = (v_ligne->>'produit_id')::uuid;

    IF v_stock IS NULL THEN
      RAISE EXCEPTION 'Produit introuvable: %', v_ligne->>'produit_id';
    END IF;

    IF v_stock < (v_ligne->>'quantite')::integer THEN
      RAISE EXCEPTION 'Stock insuffisant pour "%": disponible %, demandé %',
        COALESCE(v_ligne->>'designation','(produit)'), v_stock, (v_ligne->>'quantite')::integer;
    END IF;

    INSERT INTO public.specimen_lignes (
      specimen_id, produit_id, reference_produit, designation, quantite
    ) VALUES (
      v_spec.specimen_id,
      (v_ligne->>'produit_id')::uuid,
      NULLIF(v_ligne->>'reference_produit',''),
      COALESCE(NULLIF(v_ligne->>'designation',''), 'Produit'),
      (v_ligne->>'quantite')::integer
    );

    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif)
    VALUES (
      (v_ligne->>'produit_id')::uuid,
      'sortie',
      (v_ligne->>'quantite')::integer,
      'Spécimen ' || v_numero
    );

    v_total_qte := v_total_qte + (v_ligne->>'quantite')::integer;
    v_nb := v_nb + 1;
  END LOOP;

  UPDATE public.specimens
     SET total_quantite = v_total_qte,
         nb_produits = v_nb,
         updated_at = now()
   WHERE specimen_id = v_spec.specimen_id
   RETURNING * INTO v_spec;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'create_specimen', 'specimens', v_spec.specimen_id::text);

  RETURN v_spec;
END;
$$;

REVOKE ALL ON FUNCTION public.creer_specimen(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.creer_specimen(jsonb) TO authenticated;

-- 7. RPC: annulation (réinjecte le stock)
CREATE OR REPLACE FUNCTION public.annuler_specimen(_specimen_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spec public.specimens%ROWTYPE;
  v_ligne record;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  SELECT * INTO v_spec FROM public.specimens WHERE specimen_id = _specimen_id FOR UPDATE;
  IF v_spec IS NULL THEN RAISE EXCEPTION 'Spécimen introuvable'; END IF;
  IF v_spec.statut = 'annule' THEN RETURN; END IF;

  FOR v_ligne IN SELECT produit_id, quantite FROM public.specimen_lignes WHERE specimen_id = _specimen_id
  LOOP
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif)
    VALUES (v_ligne.produit_id, 'entree', v_ligne.quantite, 'Annulation spécimen ' || v_spec.numero);
  END LOOP;

  UPDATE public.specimens SET statut = 'annule', updated_at = now()
    WHERE specimen_id = _specimen_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'cancel_specimen', 'specimens', _specimen_id::text);
END;
$$;

REVOKE ALL ON FUNCTION public.annuler_specimen(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.annuler_specimen(uuid) TO authenticated;
