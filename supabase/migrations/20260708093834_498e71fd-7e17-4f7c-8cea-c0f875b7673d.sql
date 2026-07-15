
-- ============================================================
-- Lot 2 : Verrous & contraintes — Comptabilité & Finances
-- ============================================================

-- 2.1 Interdire suppression écriture comptable
CREATE OR REPLACE FUNCTION public.trg_ecritures_no_delete()
RETURNS trigger LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'Suppression interdite : une écriture comptable (%) ne peut pas être supprimée', OLD.reference
    USING ERRCODE='insufficient_privilege';
END;
$$;

DROP TRIGGER IF EXISTS trg_ecritures_no_delete ON public.ecritures_comptables;
CREATE TRIGGER trg_ecritures_no_delete BEFORE DELETE ON public.ecritures_comptables
FOR EACH ROW EXECUTE FUNCTION public.trg_ecritures_no_delete();

-- 2.2 Interdire suppression paiement
CREATE OR REPLACE FUNCTION public.trg_paiements_no_delete()
RETURNS trigger LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'Suppression interdite : le paiement % doit être annulé, pas supprimé', OLD.reference
    USING ERRCODE='insufficient_privilege';
END;
$$;

DROP TRIGGER IF EXISTS trg_paiements_no_delete ON public.paiements;
CREATE TRIGGER trg_paiements_no_delete BEFORE DELETE ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.trg_paiements_no_delete();

-- 2.3 Interdire modification écriture ancienne (>24h)
CREATE OR REPLACE FUNCTION public.trg_ecritures_no_modif_ancienne()
RETURNS trigger LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.created_at < now() - interval '24 hours'
     AND current_setting('request.jwt.claims', true)::jsonb->>'role' <> 'service_role' THEN
    RAISE EXCEPTION 'Modification interdite : l''écriture % a plus de 24h', OLD.reference
      USING ERRCODE='insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ecritures_no_modif_ancienne ON public.ecritures_comptables;
CREATE TRIGGER trg_ecritures_no_modif_ancienne BEFORE UPDATE ON public.ecritures_comptables
FOR EACH ROW EXECUTE FUNCTION public.trg_ecritures_no_modif_ancienne();

-- 2.4 Garde-fou paiements : positif, ≤ reste à payer, anti-doublon, verrou facture
CREATE OR REPLACE FUNCTION public.trg_paiements_guard()
RETURNS trigger LANGUAGE plpgsql
AS $$
DECLARE
  v_fac_total numeric;
  v_deja_paye numeric;
  v_reste numeric;
  v_doublon boolean;
BEGIN
  -- Montant valide
  IF NEW.montant IS NULL OR NEW.montant <= 0 THEN
    RAISE EXCEPTION 'Montant invalide : le paiement doit être strictement positif' USING ERRCODE='check_violation';
  END IF;

  IF NEW.facture_id IS NULL THEN
    RETURN NEW; -- paiements sans facture (acomptes divers) : pas de vérif reste
  END IF;

  -- Verrou pessimiste sur la facture
  SELECT montant_total INTO v_fac_total FROM public.factures
   WHERE facture_id = NEW.facture_id FOR UPDATE;

  IF v_fac_total IS NULL THEN
    RAISE EXCEPTION 'Facture % introuvable', NEW.facture_id;
  END IF;

  -- Anti-doublon
  SELECT EXISTS (
    SELECT 1 FROM public.paiements
    WHERE facture_id = NEW.facture_id
      AND date_paiement = NEW.date_paiement
      AND COALESCE(mode_paiement,'') = COALESCE(NEW.mode_paiement,'')
      AND montant = NEW.montant
      AND (statut IS NULL OR statut <> 'annule')
      AND (TG_OP <> 'UPDATE' OR paiement_id <> NEW.paiement_id)
  ) INTO v_doublon;
  IF v_doublon THEN
    RAISE EXCEPTION 'Doublon de paiement détecté (facture=%, montant=%, date=%)',
      NEW.facture_id, NEW.montant, NEW.date_paiement USING ERRCODE='unique_violation';
  END IF;

  -- Somme actuelle des paiements (hors ce paiement si UPDATE)
  SELECT COALESCE(SUM(montant),0) INTO v_deja_paye
    FROM public.paiements
   WHERE facture_id = NEW.facture_id
     AND (statut IS NULL OR statut <> 'annule')
     AND (TG_OP <> 'UPDATE' OR paiement_id <> NEW.paiement_id);

  v_reste := v_fac_total - v_deja_paye;

  IF NEW.montant > v_reste + 0.01 THEN
    RAISE EXCEPTION 'Surpaiement interdit : reste à payer = %, tentative = %',
      v_reste, NEW.montant USING ERRCODE='check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_paiements_guard ON public.paiements;
CREATE TRIGGER trg_paiements_guard BEFORE INSERT OR UPDATE ON public.paiements
FOR EACH ROW EXECUTE FUNCTION public.trg_paiements_guard();

-- ============================================================
-- Lot 3 : Recalcul & correction automatique
-- ============================================================

CREATE TABLE IF NOT EXISTS public.finances_corrections_audit (
  correction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cible_type text NOT NULL, -- 'client' | 'fournisseur' | 'facture'
  cible_id uuid NOT NULL,
  champ text NOT NULL,      -- 'solde' | 'montant_paye'
  valeur_avant numeric NOT NULL,
  valeur_apres numeric NOT NULL,
  ecart numeric NOT NULL,
  motif text,
  corrige_par uuid REFERENCES auth.users(id),
  corrige_par_nom text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.finances_corrections_audit TO authenticated;
GRANT ALL ON public.finances_corrections_audit TO service_role;

ALTER TABLE public.finances_corrections_audit ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admins read fin corrections" ON public.finances_corrections_audit;
CREATE POLICY "admins read fin corrections" ON public.finances_corrections_audit
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid()
      AND role IN ('super_admin','directeur_general','comptable'))
);

CREATE INDEX IF NOT EXISTS idx_fin_corrections_cible ON public.finances_corrections_audit(cible_type, cible_id, created_at DESC);

-- Recalcule le solde d'un client + montant_paye de ses factures
CREATE OR REPLACE FUNCTION public.recalculer_solde_client(_client_id uuid, _motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_nom text;
  v_solde_avant numeric;
  v_tot_fac numeric;
  v_tot_pay numeric;
  v_solde_apres numeric;
  v_fac_corrigees int := 0;
  r record;
  v_pay numeric;
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = v_uid AND role IN ('super_admin','directeur_general','comptable')
  ) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT solde INTO v_solde_avant FROM public.clients WHERE client_id = _client_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Client introuvable'; END IF;

  SELECT COALESCE(nom_complet, email) INTO v_nom FROM public.profiles WHERE id = v_uid;

  -- Recalcul de montant_paye pour chaque facture du client
  FOR r IN SELECT facture_id, montant_paye FROM public.factures WHERE client_id = _client_id LOOP
    SELECT COALESCE(SUM(montant),0) INTO v_pay
      FROM public.paiements
     WHERE facture_id = r.facture_id AND (statut IS NULL OR statut <> 'annule');
    IF COALESCE(r.montant_paye,0) <> v_pay THEN
      UPDATE public.factures SET montant_paye = v_pay, updated_at = now()
       WHERE facture_id = r.facture_id;
      INSERT INTO public.finances_corrections_audit
        (cible_type,cible_id,champ,valeur_avant,valeur_apres,ecart,motif,corrige_par,corrige_par_nom)
      VALUES ('facture', r.facture_id, 'montant_paye', COALESCE(r.montant_paye,0), v_pay,
              v_pay - COALESCE(r.montant_paye,0), _motif, v_uid, v_nom);
      v_fac_corrigees := v_fac_corrigees + 1;
    END IF;
  END LOOP;

  -- Recalcul du solde client
  SELECT COALESCE(SUM(montant_total),0), COALESCE(SUM(montant_paye),0)
    INTO v_tot_fac, v_tot_pay
    FROM public.factures
   WHERE client_id = _client_id AND (statut IS NULL OR statut <> 'annulee');

  v_solde_apres := v_tot_fac - v_tot_pay;

  IF COALESCE(v_solde_avant,0) <> v_solde_apres THEN
    UPDATE public.clients SET solde = v_solde_apres, updated_at = now()
     WHERE client_id = _client_id;
    INSERT INTO public.finances_corrections_audit
      (cible_type,cible_id,champ,valeur_avant,valeur_apres,ecart,motif,corrige_par,corrige_par_nom)
    VALUES ('client', _client_id, 'solde', COALESCE(v_solde_avant,0), v_solde_apres,
            v_solde_apres - COALESCE(v_solde_avant,0), _motif, v_uid, v_nom);
  END IF;

  RETURN jsonb_build_object(
    'client_id', _client_id,
    'solde_avant', COALESCE(v_solde_avant,0),
    'solde_apres', v_solde_apres,
    'factures_corrigees', v_fac_corrigees
  );
END;
$$;

REVOKE ALL ON FUNCTION public.recalculer_solde_client(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.recalculer_solde_client(uuid, text) TO authenticated;

-- Recalcul global sur tous les clients en écart
CREATE OR REPLACE FUNCTION public.recalculer_soldes_global_clients(_motif text DEFAULT 'Recalcul global')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_nb int := 0;
  r record;
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = v_uid AND role IN ('super_admin','directeur_general')
  ) THEN
    RAISE EXCEPTION 'Accès refusé (super_admin ou directeur_general requis)';
  END IF;

  FOR r IN SELECT client_id FROM public.audit_compta_soldes_clients() LOOP
    PERFORM public.recalculer_solde_client(r.client_id, _motif);
    v_nb := v_nb + 1;
  END LOOP;

  -- Aussi corriger les factures dont montant_paye est incohérent
  FOR r IN
    SELECT DISTINCT f.client_id
      FROM public.audit_compta_factures_paiements() a
      JOIN public.factures f ON f.facture_id = a.facture_id
     WHERE f.client_id IS NOT NULL
  LOOP
    PERFORM public.recalculer_solde_client(r.client_id, _motif);
  END LOOP;

  RETURN jsonb_build_object('clients_traites', v_nb, 'terminated_at', now());
END;
$$;

REVOKE ALL ON FUNCTION public.recalculer_soldes_global_clients(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.recalculer_soldes_global_clients(text) TO authenticated;
