
-- 1. Extend incidents table
ALTER TABLE public.incidents
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS motif text,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS depot_id uuid REFERENCES public.depots(depot_id),
  ADD COLUMN IF NOT EXISTS responsable_id uuid,
  ADD COLUMN IF NOT EXISTS responsable_nom text,
  ADD COLUMN IF NOT EXISTS total_quantite integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_produits integer NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS incidents_numero_unique ON public.incidents(numero) WHERE numero IS NOT NULL;

-- 2. Incident lignes
CREATE TABLE IF NOT EXISTS public.incident_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.incidents(incident_id) ON DELETE CASCADE,
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id),
  reference_produit text,
  designation text NOT NULL,
  quantite integer NOT NULL CHECK (quantite > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.incident_lignes TO authenticated;
GRANT ALL ON public.incident_lignes TO service_role;

ALTER TABLE public.incident_lignes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff select incident_lignes" ON public.incident_lignes;
CREATE POLICY "Staff select incident_lignes" ON public.incident_lignes
  FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff insert incident_lignes" ON public.incident_lignes;
CREATE POLICY "Staff insert incident_lignes" ON public.incident_lignes
  FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff update incident_lignes" ON public.incident_lignes;
CREATE POLICY "Staff update incident_lignes" ON public.incident_lignes
  FOR UPDATE TO authenticated USING (public.is_staff(auth.uid()));

DROP POLICY IF EXISTS "Staff delete incident_lignes" ON public.incident_lignes;
CREATE POLICY "Staff delete incident_lignes" ON public.incident_lignes
  FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_incident_lignes_incident ON public.incident_lignes(incident_id);
CREATE INDEX IF NOT EXISTS idx_incident_lignes_produit ON public.incident_lignes(produit_id);

-- 3. RPC: creer_incident_stock
CREATE OR REPLACE FUNCTION public.creer_incident_stock(_payload jsonb)
RETURNS public.incidents
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_inc public.incidents%ROWTYPE;
  v_numero text;
  v_seq int;
  v_date date;
  v_depot uuid;
  v_lignes jsonb;
  v_ligne jsonb;
  v_total_qte int := 0;
  v_nb int := 0;
  v_stock int;
  v_type text;
  v_motif text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE='insufficient_privilege';
  END IF;

  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock',
             'responsable_magasinier','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour déclarer un incident'
      USING ERRCODE='insufficient_privilege';
  END IF;

  v_date := COALESCE((_payload->>'date_incident')::date, CURRENT_DATE);
  v_depot := NULLIF(_payload->>'depot_id','')::uuid;
  v_type := COALESCE(NULLIF(_payload->>'type_incident',''), 'autre');
  v_motif := NULLIF(BTRIM(COALESCE(_payload->>'motif','')),'');
  v_lignes := _payload->'lignes';

  IF v_depot IS NULL THEN
    SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal = true LIMIT 1;
  END IF;
  IF v_depot IS NULL THEN
    RAISE EXCEPTION 'Aucun dépôt principal défini : sélectionnez un dépôt';
  END IF;

  IF v_lignes IS NULL OR jsonb_typeof(v_lignes) <> 'array' OR jsonb_array_length(v_lignes) = 0 THEN
    RAISE EXCEPTION 'Ajoutez au moins une ligne produit';
  END IF;

  SELECT COUNT(*) + 1 INTO v_seq FROM public.incidents WHERE date_incident = v_date;
  v_numero := 'INC-' || to_char(v_date,'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');

  INSERT INTO public.incidents (
    numero, type_incident, gravite, description, date_incident, statut,
    motif, observations, depot_id,
    responsable_id, responsable_nom
  ) VALUES (
    v_numero, v_type, 'moyenne',
    v_motif,
    v_date, 'declare',
    v_motif,
    NULLIF(BTRIM(COALESCE(_payload->>'observations','')),''),
    v_depot,
    auth.uid(),
    COALESCE(auth.jwt() -> 'user_metadata' ->> 'nom_complet', auth.jwt() ->> 'email')
  )
  RETURNING * INTO v_inc;

  FOR v_ligne IN SELECT * FROM jsonb_array_elements(v_lignes) LOOP
    IF COALESCE((v_ligne->>'quantite')::int, 0) <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide pour la ligne "%"',
        COALESCE(v_ligne->>'designation','(produit)');
    END IF;

    SELECT COALESCE(quantite,0) INTO v_stock FROM public.stocks_depots
      WHERE produit_id = (v_ligne->>'produit_id')::uuid AND depot_id = v_depot;

    IF v_stock IS NULL OR v_stock < (v_ligne->>'quantite')::int THEN
      RAISE EXCEPTION 'Stock insuffisant pour "%": disponible %, demandé %',
        COALESCE(v_ligne->>'designation','(produit)'),
        COALESCE(v_stock,0),
        (v_ligne->>'quantite')::int;
    END IF;

    INSERT INTO public.incident_lignes (
      incident_id, produit_id, reference_produit, designation, quantite
    ) VALUES (
      v_inc.incident_id,
      (v_ligne->>'produit_id')::uuid,
      NULLIF(v_ligne->>'reference_produit',''),
      COALESCE(NULLIF(v_ligne->>'designation',''), 'Produit'),
      (v_ligne->>'quantite')::int
    );

    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
    VALUES (
      (v_ligne->>'produit_id')::uuid,
      'sortie',
      (v_ligne->>'quantite')::int,
      'Incident ' || v_numero || ' - ' || v_type,
      v_depot
    );

    v_total_qte := v_total_qte + (v_ligne->>'quantite')::int;
    v_nb := v_nb + 1;
  END LOOP;

  UPDATE public.incidents
    SET total_quantite = v_total_qte, nb_produits = v_nb, updated_at = now()
    WHERE incident_id = v_inc.incident_id
    RETURNING * INTO v_inc;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'create_incident_stock', 'incidents', v_inc.incident_id::text);

  RETURN v_inc;
END;
$$;

-- 4. RPC: annuler_incident
CREATE OR REPLACE FUNCTION public.annuler_incident(_incident_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_inc public.incidents%ROWTYPE;
  v_ligne record;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock',
             'responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE='insufficient_privilege';
  END IF;

  SELECT * INTO v_inc FROM public.incidents WHERE incident_id = _incident_id FOR UPDATE;
  IF v_inc IS NULL THEN RAISE EXCEPTION 'Incident introuvable'; END IF;
  IF v_inc.statut = 'annule' THEN RETURN; END IF;

  FOR v_ligne IN
    SELECT produit_id, quantite FROM public.incident_lignes WHERE incident_id = _incident_id
  LOOP
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
    VALUES (
      v_ligne.produit_id, 'entree', v_ligne.quantite,
      'Annulation incident ' || COALESCE(v_inc.numero, v_inc.reference),
      v_inc.depot_id
    );
  END LOOP;

  UPDATE public.incidents SET statut = 'annule', updated_at = now()
    WHERE incident_id = _incident_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'cancel_incident_stock', 'incidents', _incident_id::text);
END;
$$;
