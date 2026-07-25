
-- ============================================================
-- LOT D — Extensions métier du moteur d'approbation
-- ============================================================

-- 1) Table de configuration des seuils
CREATE TABLE IF NOT EXISTS public.approbation_seuils (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module text NOT NULL,
  type_operation text NOT NULL DEFAULT 'default',
  seuil_urgent numeric NOT NULL DEFAULT 250000,
  seuil_critique numeric NOT NULL DEFAULT 1000000,
  sla_normal_heures integer NOT NULL DEFAULT 72,
  sla_urgent_heures integer NOT NULL DEFAULT 48,
  sla_critique_heures integer NOT NULL DEFAULT 24,
  actif boolean NOT NULL DEFAULT true,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(module, type_operation)
);

GRANT SELECT ON public.approbation_seuils TO authenticated;
GRANT ALL ON public.approbation_seuils TO service_role;

ALTER TABLE public.approbation_seuils ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "seuils_select_auth" ON public.approbation_seuils;
CREATE POLICY "seuils_select_auth" ON public.approbation_seuils
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "seuils_manage_admin" ON public.approbation_seuils;
CREATE POLICY "seuils_manage_admin" ON public.approbation_seuils
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'super_admin'))
  WITH CHECK (public.has_role(auth.uid(),'super_admin'));

DROP TRIGGER IF EXISTS trg_seuils_updated_at ON public.approbation_seuils;
CREATE TRIGGER trg_seuils_updated_at BEFORE UPDATE ON public.approbation_seuils
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Seuils par défaut
INSERT INTO public.approbation_seuils(module,type_operation,seuil_urgent,seuil_critique,sla_normal_heures,sla_urgent_heures,sla_critique_heures,description) VALUES
  ('paiements','default',250000,1000000,72,48,24,'Validation des paiements clients/fournisseurs'),
  ('couts_logistiques','default',100000,500000,72,48,24,'Frais logistiques (tournées, livraisons)'),
  ('achats','default',500000,2000000,96,48,24,'Bons de commande fournisseurs'),
  ('transferts','default',0,0,72,48,24,'Transferts inter-dépôts (urgence par volume)'),
  ('bulletins_paie','default',500000,2000000,120,72,24,'Bulletins de paie mensuels'),
  ('retours','default',100000,500000,72,48,24,'Retours clients'),
  ('annulations','default',0,0,48,24,12,'Annulations de commandes')
ON CONFLICT (module,type_operation) DO NOTHING;

-- 2) Fonction utilitaire de calcul urgence + SLA
CREATE OR REPLACE FUNCTION public._calc_urgence_sla(
  p_module text,
  p_montant numeric,
  p_type_operation text DEFAULT 'default'
) RETURNS TABLE(urgence text, deadline timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seuil RECORD;
  v_urg text;
  v_hrs integer;
BEGIN
  SELECT * INTO v_seuil FROM public.approbation_seuils
   WHERE module = p_module AND type_operation = p_type_operation AND actif = true
   LIMIT 1;

  IF NOT FOUND THEN
    SELECT * INTO v_seuil FROM public.approbation_seuils
     WHERE module = p_module AND type_operation = 'default' AND actif = true
     LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    v_urg := 'normal'; v_hrs := 72;
  ELSE
    IF p_montant >= v_seuil.seuil_critique AND v_seuil.seuil_critique > 0 THEN
      v_urg := 'critique'; v_hrs := v_seuil.sla_critique_heures;
    ELSIF p_montant >= v_seuil.seuil_urgent AND v_seuil.seuil_urgent > 0 THEN
      v_urg := 'urgent'; v_hrs := v_seuil.sla_urgent_heures;
    ELSE
      v_urg := 'normal'; v_hrs := v_seuil.sla_normal_heures;
    END IF;
  END IF;

  RETURN QUERY SELECT v_urg, now() + (v_hrs || ' hours')::interval;
END;
$$;

REVOKE ALL ON FUNCTION public._calc_urgence_sla(text,numeric,text) FROM public;
GRANT EXECUTE ON FUNCTION public._calc_urgence_sla(text,numeric,text) TO authenticated;

-- 3) Trigger : ACHATS — approbation à la confirmation
CREATE OR REPLACE FUNCTION public.trg_achat_creer_approbation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_calc RECORD;
BEGIN
  IF (TG_OP = 'UPDATE' AND NEW.statut = 'commande' AND OLD.statut IS DISTINCT FROM 'commande')
     OR (TG_OP = 'INSERT' AND NEW.statut = 'commande') THEN
    -- éviter les doublons
    IF EXISTS(SELECT 1 FROM public.workflow_approvals
              WHERE module='achats' AND entity_id = NEW.achat_id AND statut='en_attente') THEN
      RETURN NEW;
    END IF;

    SELECT * INTO v_calc FROM public._calc_urgence_sla('achats', COALESCE(NEW.montant,0));

    INSERT INTO public.workflow_approvals(
      module, workflow_code, entity_type, entity_id, reference,
      statut, demandeur_id, demandeur_nom, metadata,
      niveau_urgence, sla_deadline, simulation_financiere
    ) VALUES (
      'achats','achat_valider','achat', NEW.achat_id,
      COALESCE(NEW.reference, NEW.achat_id::text),
      'en_attente', COALESCE(NEW.created_by, auth.uid()),
      (SELECT COALESCE(nom_complet,email) FROM public.profiles WHERE id = COALESCE(NEW.created_by, auth.uid())),
      jsonb_build_object('achat_id', NEW.achat_id, 'montant', NEW.montant, 'fournisseur_id', NEW.fournisseur_id),
      v_calc.urgence, v_calc.deadline,
      jsonb_build_object('montant', NEW.montant)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_achat_auto_approbation ON public.achats;
CREATE TRIGGER trg_achat_auto_approbation
AFTER INSERT OR UPDATE OF statut ON public.achats
FOR EACH ROW EXECUTE FUNCTION public.trg_achat_creer_approbation();

-- 4) Trigger : TRANSFERTS — approbation à l'expédition
CREATE OR REPLACE FUNCTION public.trg_transfert_creer_approbation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_calc RECORD;
  v_valeur numeric := 0;
BEGIN
  IF (TG_OP='UPDATE' AND NEW.statut='expedie' AND OLD.statut IS DISTINCT FROM 'expedie') THEN
    IF EXISTS(SELECT 1 FROM public.workflow_approvals
              WHERE module='transferts' AND entity_id = NEW.transfert_id AND statut='en_attente') THEN
      RETURN NEW;
    END IF;

    -- valeur estimée du transfert (best-effort)
    BEGIN
      SELECT COALESCE(SUM(tl.quantite * COALESCE(p.prix_vente,0)),0) INTO v_valeur
        FROM public.transfert_lignes tl
        LEFT JOIN public.produits p ON p.produit_id = tl.produit_id
       WHERE tl.transfert_id = NEW.transfert_id;
    EXCEPTION WHEN OTHERS THEN v_valeur := 0;
    END;

    SELECT * INTO v_calc FROM public._calc_urgence_sla('transferts', v_valeur);

    INSERT INTO public.workflow_approvals(
      module, workflow_code, entity_type, entity_id, reference,
      statut, demandeur_id, demandeur_nom, metadata,
      niveau_urgence, sla_deadline, simulation_financiere
    ) VALUES (
      'transferts','transfert_valider','transfert', NEW.transfert_id,
      COALESCE(NEW.numero, NEW.reference, NEW.transfert_id::text),
      'en_attente', COALESCE(NEW.created_by, auth.uid()),
      (SELECT COALESCE(nom_complet,email) FROM public.profiles WHERE id = COALESCE(NEW.created_by, auth.uid())),
      jsonb_build_object('transfert_id', NEW.transfert_id, 'source', NEW.depot_source_id, 'destination', NEW.depot_destination_id, 'valeur', v_valeur),
      v_calc.urgence, v_calc.deadline,
      jsonb_build_object('montant', v_valeur)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_transfert_auto_approbation ON public.transferts;
CREATE TRIGGER trg_transfert_auto_approbation
AFTER UPDATE OF statut ON public.transferts
FOR EACH ROW EXECUTE FUNCTION public.trg_transfert_creer_approbation();

-- 5) Trigger : BULLETINS PAIE — approbation à la génération
CREATE OR REPLACE FUNCTION public.trg_bulletin_creer_approbation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_calc RECORD;
BEGIN
  IF (TG_OP='INSERT') OR (TG_OP='UPDATE' AND NEW.statut='genere' AND OLD.statut IS DISTINCT FROM 'genere') THEN
    IF EXISTS(SELECT 1 FROM public.workflow_approvals
              WHERE module='bulletins_paie' AND entity_id = NEW.bulletin_id AND statut='en_attente') THEN
      RETURN NEW;
    END IF;

    SELECT * INTO v_calc FROM public._calc_urgence_sla('bulletins_paie', COALESCE(NEW.salaire_net,0));

    INSERT INTO public.workflow_approvals(
      module, workflow_code, entity_type, entity_id, reference,
      statut, demandeur_id, demandeur_nom, metadata,
      niveau_urgence, sla_deadline, simulation_financiere
    ) VALUES (
      'bulletins_paie','bulletin_valider','bulletin', NEW.bulletin_id,
      COALESCE(NEW.reference, NEW.periode || '-' || NEW.bulletin_id::text),
      'en_attente', auth.uid(),
      (SELECT COALESCE(nom_complet,email) FROM public.profiles WHERE id = auth.uid()),
      jsonb_build_object('bulletin_id', NEW.bulletin_id, 'employe_id', NEW.employe_id, 'periode', NEW.periode, 'salaire_net', NEW.salaire_net),
      v_calc.urgence, v_calc.deadline,
      jsonb_build_object('montant', NEW.salaire_net)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bulletin_auto_approbation ON public.bulletins_paie;
CREATE TRIGGER trg_bulletin_auto_approbation
AFTER INSERT OR UPDATE OF statut ON public.bulletins_paie
FOR EACH ROW EXECUTE FUNCTION public.trg_bulletin_creer_approbation();
