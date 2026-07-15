
-- 1. Lien proforma <- commande (pour suivi)
ALTER TABLE public.proformas
  ADD COLUMN IF NOT EXISTS commande_id uuid REFERENCES public.commandes(commande_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_proformas_commande_id ON public.proformas(commande_id);

-- 2. Transition de statut + suppression contrôlée
CREATE OR REPLACE FUNCTION public.guard_commande_status()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  allowed boolean := false;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    -- Transitions autorisées
    allowed := (OLD.statut, NEW.statut) IN (
      ('brouillon','en_attente_validation'),
      ('brouillon','annulee'),
      ('en_attente_validation','validee'),
      ('en_attente_validation','annulee'),
      ('en_attente_validation','brouillon'),
      ('validee','facturee'),
      ('validee','livree'),
      ('validee','annulee'),
      ('facturee','livree'),
      ('facturee','annulee')
    );
    IF NOT allowed THEN
      RAISE EXCEPTION 'Transition de statut interdite: % -> %', OLD.statut, NEW.statut
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_commande_status ON public.commandes;
CREATE TRIGGER trg_guard_commande_status
  BEFORE UPDATE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.guard_commande_status();

CREATE OR REPLACE FUNCTION public.guard_commande_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.statut IN ('validee','facturee','livree') THEN
    RAISE EXCEPTION 'Suppression interdite: commande % au statut %', OLD.reference, OLD.statut
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_commande_delete ON public.commandes;
CREATE TRIGGER trg_guard_commande_delete
  BEFORE DELETE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.guard_commande_delete();

-- 3. Génération automatique de la proforma à la création
CREATE OR REPLACE FUNCTION public.creer_proforma_pour_commande()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proforma_id uuid;
  v_ref text;
BEGIN
  IF NEW.statut <> 'en_attente_validation' THEN
    RETURN NEW;
  END IF;

  -- Évite double proforma
  IF EXISTS (SELECT 1 FROM public.proformas WHERE commande_id = NEW.commande_id) THEN
    RETURN NEW;
  END IF;

  v_ref := 'PRO-' || to_char(now(),'YYYYMMDD-HH24MISS') || '-' || substr(NEW.commande_id::text, 1, 4);

  INSERT INTO public.proformas (
    reference, client_id, client_nom, date_proforma, date_validite,
    montant_total, statut, notes, commande_id
  ) VALUES (
    v_ref, NEW.client_id, NEW.client_nom, NEW.date_commande,
    (NEW.date_commande + INTERVAL '30 days')::date,
    NEW.montant_total, 'en_attente',
    'Proforma générée automatiquement pour la commande ' || NEW.reference,
    NEW.commande_id
  ) RETURNING proforma_id INTO v_proforma_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_creer_proforma_pour_commande ON public.commandes;
CREATE TRIGGER trg_creer_proforma_pour_commande
  AFTER INSERT ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.creer_proforma_pour_commande();

-- Trigger pour recopier les lignes vers la proforma après insertion des lignes
CREATE OR REPLACE FUNCTION public.sync_proforma_lignes_from_commande()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proforma_id uuid;
BEGIN
  SELECT proforma_id INTO v_proforma_id
    FROM public.proformas WHERE commande_id = NEW.commande_id LIMIT 1;
  IF v_proforma_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO public.proforma_lignes (proforma_id, produit_id, designation, quantite, prix_unitaire, total_ligne)
    VALUES (v_proforma_id, NEW.produit_id, NEW.designation, NEW.quantite, NEW.prix_unitaire, NEW.total_ligne);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_proforma_lignes ON public.commande_lignes;
CREATE TRIGGER trg_sync_proforma_lignes
  AFTER INSERT ON public.commande_lignes
  FOR EACH ROW EXECUTE FUNCTION public.sync_proforma_lignes_from_commande();

-- 4. RPC valider_commande
CREATE OR REPLACE FUNCTION public.valider_commande(_commande_id uuid)
RETURNS TABLE(facture_reference text, bl_reference text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cmd record;
  v_fac_ref text;
  v_bl_ref text;
  v_stamp text;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','directeur_commercial']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée : rôle requis pour valider une commande'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id FOR UPDATE;
  IF v_cmd IS NULL THEN
    RAISE EXCEPTION 'Commande introuvable';
  END IF;
  IF v_cmd.statut <> 'en_attente_validation' THEN
    RAISE EXCEPTION 'Seules les commandes en attente de validation peuvent être validées (statut actuel: %)', v_cmd.statut;
  END IF;

  v_stamp := to_char(now(),'YYYYMMDD-HH24MISS');

  -- Facture définitive (idempotent : skip si existe déjà)
  SELECT reference INTO v_fac_ref FROM public.factures
    WHERE commande_id = _commande_id LIMIT 1;
  IF v_fac_ref IS NULL THEN
    v_fac_ref := 'FAC-' || v_stamp || '-' || substr(_commande_id::text,1,4);
    INSERT INTO public.factures (
      reference, client_id, client_nom, commande_id,
      date_facture, date_echeance, montant_total, montant_paye, statut, notes
    ) VALUES (
      v_fac_ref, v_cmd.client_id, v_cmd.client_nom, _commande_id,
      CURRENT_DATE, (CURRENT_DATE + INTERVAL '30 days')::date,
      v_cmd.montant_total, 0, 'impayee',
      'Facture générée automatiquement à la validation de ' || v_cmd.reference
    );
  END IF;

  -- Bon de livraison
  SELECT reference INTO v_bl_ref FROM public.bons_livraison
    WHERE commande_id = _commande_id LIMIT 1;
  IF v_bl_ref IS NULL THEN
    v_bl_ref := 'BL-' || v_stamp || '-' || substr(_commande_id::text,1,4);
    INSERT INTO public.bons_livraison (
      reference, commande_id, client_id, date_emission,
      statut, montant_total, notes
    ) VALUES (
      v_bl_ref, _commande_id, v_cmd.client_id, CURRENT_DATE,
      'brouillon', v_cmd.montant_total,
      'BL généré automatiquement à la validation de ' || v_cmd.reference
    );
  END IF;

  UPDATE public.commandes SET statut = 'validee', updated_at = now()
    WHERE commande_id = _commande_id;

  -- Marque la proforma associée comme acceptée
  UPDATE public.proformas SET statut = 'acceptee'
    WHERE commande_id = _commande_id AND statut = 'en_attente';

  RETURN QUERY SELECT v_fac_ref, v_bl_ref;
END;
$$;

GRANT EXECUTE ON FUNCTION public.valider_commande(uuid) TO authenticated;
