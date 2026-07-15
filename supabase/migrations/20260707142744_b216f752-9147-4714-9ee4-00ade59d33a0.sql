
-- =====================================================================
-- 1. TOURNEES : nouveaux champs de workflow + total auto
-- =====================================================================
ALTER TABLE public.tournees
  ADD COLUMN IF NOT EXISTS cout_livraison numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS type_tournee text NOT NULL DEFAULT 'livraison',
  ADD COLUMN IF NOT EXISTS mode_reglement text,
  ADD COLUMN IF NOT EXISTS validation_statut text NOT NULL DEFAULT 'en_attente',
  ADD COLUMN IF NOT EXISTS validation_at timestamptz,
  ADD COLUMN IF NOT EXISTS validation_by uuid,
  ADD COLUMN IF NOT EXISTS validation_commentaire text,
  ADD COLUMN IF NOT EXISTS ecriture_id uuid REFERENCES public.ecritures_comptables(ecriture_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS updated_by uuid;

-- Contraintes (valeurs autorisées)
ALTER TABLE public.tournees DROP CONSTRAINT IF EXISTS tournees_type_tournee_chk;
ALTER TABLE public.tournees ADD CONSTRAINT tournees_type_tournee_chk
  CHECK (type_tournee IN ('livraison','expedition','mixte'));

ALTER TABLE public.tournees DROP CONSTRAINT IF EXISTS tournees_validation_statut_chk;
ALTER TABLE public.tournees ADD CONSTRAINT tournees_validation_statut_chk
  CHECK (validation_statut IN ('en_attente','valide','refuse','annule','decaisse'));

ALTER TABLE public.tournees DROP CONSTRAINT IF EXISTS tournees_mode_reglement_chk;
ALTER TABLE public.tournees ADD CONSTRAINT tournees_mode_reglement_chk
  CHECK (mode_reglement IS NULL OR mode_reglement IN ('caisse','banque'));

-- Recalcul auto du cout_total
CREATE OR REPLACE FUNCTION public.tournees_recompute_cout_total()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  NEW.cout_total := COALESCE(NEW.cout_carburant,0)
                  + COALESCE(NEW.cout_peages,0)
                  + COALESCE(NEW.cout_repas,0)
                  + COALESCE(NEW.cout_manutentions,0)
                  + COALESCE(NEW.cout_livraison,0)
                  + COALESCE(NEW.cout_expeditions,0)
                  + COALESCE(NEW.cout_autres,0);
  IF TG_OP = 'INSERT' THEN
    NEW.created_by := COALESCE(NEW.created_by, auth.uid());
  END IF;
  NEW.updated_by := auth.uid();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_tournees_recompute_cout_total ON public.tournees;
CREATE TRIGGER trg_tournees_recompute_cout_total
  BEFORE INSERT OR UPDATE ON public.tournees
  FOR EACH ROW EXECUTE FUNCTION public.tournees_recompute_cout_total();

-- =====================================================================
-- 2. AUDIT COUTS LOGISTIQUES
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.couts_logistiques_audit (
  audit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournee_id uuid NOT NULL REFERENCES public.tournees(tournee_id) ON DELETE CASCADE,
  action text NOT NULL,
  actor uuid,
  actor_email text,
  commentaire text,
  avant jsonb,
  apres jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_couts_audit_tournee ON public.couts_logistiques_audit(tournee_id, created_at DESC);

GRANT SELECT, INSERT ON public.couts_logistiques_audit TO authenticated;
GRANT ALL ON public.couts_logistiques_audit TO service_role;
ALTER TABLE public.couts_logistiques_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff read couts audit" ON public.couts_logistiques_audit;
CREATE POLICY "staff read couts audit" ON public.couts_logistiques_audit
  FOR SELECT USING (public.is_staff(auth.uid()));

-- Insert seulement via fonctions SECURITY DEFINER : refus par défaut.
DROP POLICY IF EXISTS "no direct insert couts audit" ON public.couts_logistiques_audit;
CREATE POLICY "no direct insert couts audit" ON public.couts_logistiques_audit
  FOR INSERT WITH CHECK (false);

-- Trigger d'audit sur les modifications de coûts (hors workflow)
CREATE OR REPLACE FUNCTION public.tournees_audit_costs()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_action text;
  v_email text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_action := 'creation';
  ELSIF TG_OP = 'UPDATE' THEN
    IF (OLD.cout_carburant, OLD.cout_peages, OLD.cout_repas, OLD.cout_manutentions,
        OLD.cout_livraison, OLD.cout_expeditions, OLD.cout_autres)
       IS DISTINCT FROM
       (NEW.cout_carburant, NEW.cout_peages, NEW.cout_repas, NEW.cout_manutentions,
        NEW.cout_livraison, NEW.cout_expeditions, NEW.cout_autres)
    THEN
      v_action := 'modification';
    ELSE
      RETURN NEW;
    END IF;
  END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.couts_logistiques_audit(tournee_id, action, actor, actor_email, avant, apres)
  VALUES (
    NEW.tournee_id,
    v_action,
    auth.uid(),
    v_email,
    CASE WHEN TG_OP='UPDATE' THEN jsonb_build_object(
      'cout_carburant', OLD.cout_carburant,
      'cout_peages', OLD.cout_peages,
      'cout_repas', OLD.cout_repas,
      'cout_manutentions', OLD.cout_manutentions,
      'cout_livraison', OLD.cout_livraison,
      'cout_expeditions', OLD.cout_expeditions,
      'cout_autres', OLD.cout_autres,
      'cout_total', OLD.cout_total
    ) END,
    jsonb_build_object(
      'cout_carburant', NEW.cout_carburant,
      'cout_peages', NEW.cout_peages,
      'cout_repas', NEW.cout_repas,
      'cout_manutentions', NEW.cout_manutentions,
      'cout_livraison', NEW.cout_livraison,
      'cout_expeditions', NEW.cout_expeditions,
      'cout_autres', NEW.cout_autres,
      'cout_total', NEW.cout_total
    )
  );
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_tournees_audit_costs ON public.tournees;
CREATE TRIGGER trg_tournees_audit_costs
  AFTER INSERT OR UPDATE ON public.tournees
  FOR EACH ROW EXECUTE FUNCTION public.tournees_audit_costs();

-- Empêche la logistique de modifier les coûts d'une tournée déjà validée/décaissée.
CREATE OR REPLACE FUNCTION public.tournees_guard_locked_costs()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF OLD.validation_statut IN ('valide','decaisse')
     AND (OLD.cout_carburant, OLD.cout_peages, OLD.cout_repas, OLD.cout_manutentions,
          OLD.cout_livraison, OLD.cout_expeditions, OLD.cout_autres)
         IS DISTINCT FROM
         (NEW.cout_carburant, NEW.cout_peages, NEW.cout_repas, NEW.cout_manutentions,
          NEW.cout_livraison, NEW.cout_expeditions, NEW.cout_autres)
     AND NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[])
  THEN
    RAISE EXCEPTION 'Les coûts d''une tournée validée ne peuvent plus être modifiés.';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_tournees_guard_locked_costs ON public.tournees;
CREATE TRIGGER trg_tournees_guard_locked_costs
  BEFORE UPDATE ON public.tournees
  FOR EACH ROW EXECUTE FUNCTION public.tournees_guard_locked_costs();

-- =====================================================================
-- 3. WORKFLOW : valider / refuser / annuler
-- =====================================================================
CREATE OR REPLACE FUNCTION public.valider_decaissement_tournee(
  _tournee_id uuid,
  _mode_reglement text,
  _commentaire text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_t public.tournees;
  v_exercice_id uuid;
  v_journal text;
  v_compte_tresorerie text;
  v_libelle_tresorerie text;
  v_ecriture_id uuid;
  v_ref text;
  v_email text;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé : seule la comptabilité peut valider un décaissement.';
  END IF;
  IF _mode_reglement NOT IN ('caisse','banque') THEN
    RAISE EXCEPTION 'Mode de règlement invalide (caisse ou banque attendu).';
  END IF;

  SELECT * INTO v_t FROM public.tournees WHERE tournee_id = _tournee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tournée introuvable.'; END IF;
  IF v_t.validation_statut = 'decaisse' THEN
    RAISE EXCEPTION 'Cette tournée est déjà décaissée.';
  END IF;
  IF COALESCE(v_t.cout_total,0) <= 0 THEN
    RAISE EXCEPTION 'Aucun coût à valider pour cette tournée.';
  END IF;

  IF _mode_reglement = 'caisse' THEN
    v_journal := 'CA'; v_compte_tresorerie := '571'; v_libelle_tresorerie := 'Caisse';
  ELSE
    v_journal := 'BQ'; v_compte_tresorerie := '521'; v_libelle_tresorerie := 'Banque';
  END IF;

  SELECT exercice_id INTO v_exercice_id
  FROM public.exercices
  WHERE v_t.date_tournee BETWEEN date_debut AND date_fin
  ORDER BY date_debut DESC LIMIT 1;
  IF v_exercice_id IS NULL THEN
    SELECT exercice_id INTO v_exercice_id FROM public.exercices
    WHERE statut = 'actif' ORDER BY date_debut DESC LIMIT 1;
  END IF;
  IF v_exercice_id IS NULL THEN
    RAISE EXCEPTION 'Aucun exercice comptable ouvert pour la date de la tournée.';
  END IF;

  v_ref := 'DEC-' || v_t.reference;

  INSERT INTO public.ecritures_comptables (
    reference, date_ecriture, journal, libelle,
    source_type, source_id, montant_total, exercice_id
  ) VALUES (
    v_ref, v_t.date_tournee, v_journal,
    'Décaissement tournée ' || v_t.reference,
    'tournee', v_t.tournee_id, v_t.cout_total, v_exercice_id
  ) RETURNING ecriture_id INTO v_ecriture_id;

  -- Débits (charges) par catégorie non nulle
  IF COALESCE(v_t.cout_carburant,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
    VALUES (v_ecriture_id, '6241', 'Carburant', v_t.cout_carburant, 0);
  END IF;
  IF COALESCE(v_t.cout_peages,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
    VALUES (v_ecriture_id, '6245', 'Péages', v_t.cout_peages, 0);
  END IF;
  IF COALESCE(v_t.cout_repas,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
    VALUES (v_ecriture_id, '6257', 'Repas / Déplacements', v_t.cout_repas, 0);
  END IF;
  IF COALESCE(v_t.cout_manutentions,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
    VALUES (v_ecriture_id, '6132', 'Manutentions', v_t.cout_manutentions, 0);
  END IF;
  IF COALESCE(v_t.cout_livraison,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
    VALUES (v_ecriture_id, '6242', 'Frais de livraison', v_t.cout_livraison, 0);
  END IF;
  IF COALESCE(v_t.cout_expeditions,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
    VALUES (v_ecriture_id, '6243', 'Frais d''expédition', v_t.cout_expeditions, 0);
  END IF;
  IF COALESCE(v_t.cout_autres,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
    VALUES (v_ecriture_id, '6288', 'Autres frais logistiques', v_t.cout_autres, 0);
  END IF;

  -- Crédit trésorerie
  INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit)
  VALUES (v_ecriture_id, v_compte_tresorerie, v_libelle_tresorerie, 0, v_t.cout_total);

  UPDATE public.tournees SET
    validation_statut = 'decaisse',
    mode_reglement = _mode_reglement,
    validation_at = now(),
    validation_by = auth.uid(),
    validation_commentaire = _commentaire,
    ecriture_id = v_ecriture_id
  WHERE tournee_id = _tournee_id;

  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.couts_logistiques_audit(tournee_id, action, actor, actor_email, commentaire, apres)
  VALUES (_tournee_id, 'decaissement', auth.uid(), v_email, _commentaire,
    jsonb_build_object('ecriture_id', v_ecriture_id, 'mode_reglement', _mode_reglement, 'montant', v_t.cout_total));

  RETURN v_ecriture_id;
END $$;

CREATE OR REPLACE FUNCTION public.refuser_tournee_couts(
  _tournee_id uuid, _commentaire text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_email text;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé.';
  END IF;
  UPDATE public.tournees
    SET validation_statut='refuse',
        validation_at=now(),
        validation_by=auth.uid(),
        validation_commentaire=_commentaire
    WHERE tournee_id=_tournee_id AND validation_statut IN ('en_attente','valide');
  IF NOT FOUND THEN RAISE EXCEPTION 'Tournée introuvable ou déjà finalisée.'; END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.couts_logistiques_audit(tournee_id, action, actor, actor_email, commentaire)
  VALUES (_tournee_id, 'refus', auth.uid(), v_email, _commentaire);
END $$;

CREATE OR REPLACE FUNCTION public.annuler_validation_tournee(
  _tournee_id uuid, _commentaire text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ecr uuid; v_email text;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé : annulation réservée à la direction.';
  END IF;
  SELECT ecriture_id INTO v_ecr FROM public.tournees WHERE tournee_id=_tournee_id FOR UPDATE;
  IF v_ecr IS NOT NULL THEN
    DELETE FROM public.ecriture_lignes WHERE ecriture_id = v_ecr;
    DELETE FROM public.ecritures_comptables WHERE ecriture_id = v_ecr;
  END IF;
  UPDATE public.tournees
    SET validation_statut='annule',
        validation_at=now(),
        validation_by=auth.uid(),
        validation_commentaire=_commentaire,
        ecriture_id=NULL,
        mode_reglement=NULL
    WHERE tournee_id=_tournee_id;
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.couts_logistiques_audit(tournee_id, action, actor, actor_email, commentaire)
  VALUES (_tournee_id, 'annulation', auth.uid(), v_email, _commentaire);
END $$;

GRANT EXECUTE ON FUNCTION public.valider_decaissement_tournee(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refuser_tournee_couts(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.annuler_validation_tournee(uuid, text) TO authenticated;

-- =====================================================================
-- 4. INDEX POUR LISTE COUTS LOGISTIQUES
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_tournees_validation_statut ON public.tournees(validation_statut, date_tournee DESC);
CREATE INDEX IF NOT EXISTS idx_tournees_date ON public.tournees(date_tournee DESC);
