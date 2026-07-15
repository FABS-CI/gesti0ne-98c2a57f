
-- =====================================================================
-- Module SPÉCIMENS (remises gratuites) — FABS-CI
-- =====================================================================

-- 1) Tables ------------------------------------------------------------

CREATE TABLE public.specimens (
  specimen_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference          text UNIQUE,
  date_remise        date NOT NULL DEFAULT CURRENT_DATE,
  gestionnaire_id    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  gestionnaire_nom   text,
  motif              text,
  observations       text,
  client_id          uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  beneficiaire_nom   text,
  telephone          text,
  etablissement      text,
  ville              text,
  adresse            text,
  statut             text NOT NULL DEFAULT 'brouillon',
  montant_theorique  numeric NOT NULL DEFAULT 0,
  total_quantite     integer NOT NULL DEFAULT 0,
  created_by         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT specimens_statut_chk CHECK (statut IN ('brouillon','validee','annulee')),
  CONSTRAINT specimens_beneficiaire_chk
    CHECK (client_id IS NOT NULL OR (beneficiaire_nom IS NOT NULL AND length(trim(beneficiaire_nom)) > 0))
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.specimens TO authenticated;
GRANT ALL ON public.specimens TO service_role;
ALTER TABLE public.specimens ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.specimen_lignes (
  ligne_id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  specimen_id              uuid NOT NULL REFERENCES public.specimens(specimen_id) ON DELETE CASCADE,
  produit_id               uuid NOT NULL REFERENCES public.produits(produit_id) ON DELETE RESTRICT,
  reference_produit        text,
  designation              text NOT NULL,
  quantite                 integer NOT NULL CHECK (quantite > 0),
  prix_unitaire_theorique  numeric NOT NULL DEFAULT 0,
  total_ligne              numeric NOT NULL DEFAULT 0,
  created_at               timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.specimen_lignes TO authenticated;
GRANT ALL ON public.specimen_lignes TO service_role;
ALTER TABLE public.specimen_lignes ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_specimens_statut    ON public.specimens(statut);
CREATE INDEX idx_specimens_date      ON public.specimens(date_remise DESC);
CREATE INDEX idx_specimens_client    ON public.specimens(client_id);
CREATE INDEX idx_specimen_lignes_sp  ON public.specimen_lignes(specimen_id);
CREATE INDEX idx_specimen_lignes_pr  ON public.specimen_lignes(produit_id);

-- 2) Politiques RLS ---------------------------------------------------

-- Lecture pour tout le staff connecté.
CREATE POLICY "specimens_select_staff" ON public.specimens
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

CREATE POLICY "specimen_lignes_select_staff" ON public.specimen_lignes
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

-- Écriture réservée aux rôles autorisés.
CREATE POLICY "specimens_write_authorized" ON public.specimens
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]));

CREATE POLICY "specimen_lignes_write_authorized" ON public.specimen_lignes
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(),
    ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]));

-- 3) Triggers utilitaires ---------------------------------------------

CREATE TRIGGER trg_specimens_updated
  BEFORE UPDATE ON public.specimens
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Référence auto SPC-YYYYMMDD-XXXX
CREATE OR REPLACE FUNCTION public.set_specimen_reference()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq integer;
BEGIN
  IF NEW.reference IS NOT NULL AND length(trim(NEW.reference)) > 0 THEN
    RETURN NEW;
  END IF;
  SELECT COUNT(*) + 1 INTO v_seq
    FROM public.specimens
    WHERE date_remise = NEW.date_remise;
  NEW.reference := 'SPC-' || to_char(NEW.date_remise, 'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');
  RETURN NEW;
END $$;

CREATE TRIGGER trg_specimens_reference
  BEFORE INSERT ON public.specimens
  FOR EACH ROW EXECUTE FUNCTION public.set_specimen_reference();

-- Garde de transitions de statut
CREATE OR REPLACE FUNCTION public.guard_specimen_status()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE allowed boolean := false;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    allowed := (OLD.statut, NEW.statut) IN (
      ('brouillon','validee'),
      ('brouillon','annulee'),
      ('validee','annulee')
    );
    IF NOT allowed THEN
      RAISE EXCEPTION 'Transition spécimen interdite: % -> %', OLD.statut, NEW.statut
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_specimens_guard_status
  BEFORE UPDATE ON public.specimens
  FOR EACH ROW EXECUTE FUNCTION public.guard_specimen_status();

-- Garde de suppression
CREATE OR REPLACE FUNCTION public.guard_specimen_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.statut <> 'brouillon' THEN
    RAISE EXCEPTION 'Suppression interdite: spécimen % au statut %', OLD.reference, OLD.statut
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END $$;

CREATE TRIGGER trg_specimens_guard_delete
  BEFORE DELETE ON public.specimens
  FOR EACH ROW EXECUTE FUNCTION public.guard_specimen_delete();

-- Recalcule totaux d'une remise depuis ses lignes
CREATE OR REPLACE FUNCTION public.refresh_specimen_totaux(_specimen_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.specimens s SET
    montant_theorique = COALESCE((SELECT SUM(total_ligne) FROM public.specimen_lignes WHERE specimen_id = _specimen_id), 0),
    total_quantite    = COALESCE((SELECT SUM(quantite)    FROM public.specimen_lignes WHERE specimen_id = _specimen_id), 0),
    updated_at        = now()
  WHERE s.specimen_id = _specimen_id;
END $$;

CREATE OR REPLACE FUNCTION public.trg_specimen_lignes_totaux()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN v_id := OLD.specimen_id; ELSE v_id := NEW.specimen_id; END IF;
  PERFORM public.refresh_specimen_totaux(v_id);
  RETURN NULL;
END $$;

CREATE TRIGGER trg_specimen_lignes_totaux_ins
  AFTER INSERT OR UPDATE OR DELETE ON public.specimen_lignes
  FOR EACH ROW EXECUTE FUNCTION public.trg_specimen_lignes_totaux();

-- 4) RPC valider / annuler --------------------------------------------

CREATE OR REPLACE FUNCTION public.valider_specimen(_specimen_id uuid)
RETURNS TABLE(reference text, total_quantite integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spec record;
  v_ligne record;
  v_stock_dispo integer;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour valider une remise de spécimens'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_spec FROM public.specimens WHERE specimen_id = _specimen_id FOR UPDATE;
  IF v_spec IS NULL THEN
    RAISE EXCEPTION 'Spécimen introuvable';
  END IF;
  IF v_spec.statut <> 'brouillon' THEN
    RAISE EXCEPTION 'Seules les remises en brouillon peuvent être validées (statut actuel: %)', v_spec.statut;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.specimen_lignes WHERE specimen_id = _specimen_id) THEN
    RAISE EXCEPTION 'Impossible de valider : la remise ne contient aucune ligne';
  END IF;

  -- Contrôle stock disponible (somme tous dépôts)
  FOR v_ligne IN
    SELECT sl.produit_id, sl.designation, SUM(sl.quantite) AS qte
    FROM public.specimen_lignes sl
    WHERE sl.specimen_id = _specimen_id
    GROUP BY sl.produit_id, sl.designation
  LOOP
    SELECT COALESCE(stock, 0) INTO v_stock_dispo
      FROM public.produits WHERE produit_id = v_ligne.produit_id;
    IF v_stock_dispo < v_ligne.qte THEN
      RAISE EXCEPTION 'Stock insuffisant pour "%": disponible %, demandé %',
        v_ligne.designation, v_stock_dispo, v_ligne.qte;
    END IF;
  END LOOP;

  -- Décrément stock via stock_mouvements (le trigger apply_stock_mouvement fait le reste)
  FOR v_ligne IN
    SELECT produit_id, quantite FROM public.specimen_lignes WHERE specimen_id = _specimen_id
  LOOP
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif)
    VALUES (v_ligne.produit_id, 'sortie', v_ligne.quantite, 'Spécimen ' || v_spec.reference);
  END LOOP;

  UPDATE public.specimens SET statut = 'validee', updated_at = now()
    WHERE specimen_id = _specimen_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'validate_specimen', 'specimens', _specimen_id::text);

  INSERT INTO public.notifications (user_id, titre, message, type_notification)
    VALUES (auth.uid(),
            'Remise de spécimens validée',
            'Remise ' || v_spec.reference || ' validée : ' || v_spec.total_quantite || ' article(s) sortis du stock.',
            'info')
    ON CONFLICT DO NOTHING;

  RETURN QUERY SELECT v_spec.reference, v_spec.total_quantite;
END $$;

CREATE OR REPLACE FUNCTION public.annuler_specimen(_specimen_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spec record;
  v_ligne record;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_spec FROM public.specimens WHERE specimen_id = _specimen_id FOR UPDATE;
  IF v_spec IS NULL THEN RAISE EXCEPTION 'Spécimen introuvable'; END IF;
  IF v_spec.statut = 'annulee' THEN RETURN; END IF;

  IF v_spec.statut = 'validee' THEN
    FOR v_ligne IN
      SELECT produit_id, quantite FROM public.specimen_lignes WHERE specimen_id = _specimen_id
    LOOP
      INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif)
      VALUES (v_ligne.produit_id, 'entree', v_ligne.quantite, 'Annulation spécimen ' || v_spec.reference);
    END LOOP;
  END IF;

  UPDATE public.specimens SET statut = 'annulee', updated_at = now()
    WHERE specimen_id = _specimen_id;

  INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
    VALUES (auth.uid(), 'cancel_specimen', 'specimens', _specimen_id::text);
END $$;

GRANT EXECUTE ON FUNCTION public.valider_specimen(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.annuler_specimen(uuid) TO authenticated;
