
-- Guard transitions
CREATE OR REPLACE FUNCTION public.guard_achat_status()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE allowed boolean := false;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    allowed := (OLD.statut, NEW.statut) IN (
      ('brouillon','commande'),
      ('brouillon','annule'),
      ('commande','recu'),
      ('commande','annule'),
      ('recu','paye')
    );
    IF NOT allowed THEN
      RAISE EXCEPTION 'Transition achat interdite: % -> %', OLD.statut, NEW.statut
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_guard_achat_status ON public.achats;
CREATE TRIGGER trg_guard_achat_status
BEFORE UPDATE ON public.achats
FOR EACH ROW EXECUTE FUNCTION public.guard_achat_status();

-- Guard delete
CREATE OR REPLACE FUNCTION public.guard_achat_delete()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF OLD.statut IN ('recu','paye') THEN
    RAISE EXCEPTION 'Suppression interdite: achat % au statut %', OLD.reference, OLD.statut
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_guard_achat_delete ON public.achats;
CREATE TRIGGER trg_guard_achat_delete
BEFORE DELETE ON public.achats
FOR EACH ROW EXECUTE FUNCTION public.guard_achat_delete();

-- RPC: confirmer commande fournisseur
CREATE OR REPLACE FUNCTION public.confirmer_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','comptable','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.achats SET statut = 'commande', updated_at = now()
    WHERE achat_id = _achat_id AND statut = 'brouillon';
  IF NOT FOUND THEN RAISE EXCEPTION 'Achat introuvable ou statut invalide'; END IF;
END $$;

-- RPC: réceptionner
CREATE OR REPLACE FUNCTION public.receptionner_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.achats SET statut = 'recu', updated_at = now()
    WHERE achat_id = _achat_id AND statut = 'commande';
  IF NOT FOUND THEN RAISE EXCEPTION 'Achat introuvable ou statut invalide'; END IF;
END $$;

-- RPC: marquer payé
CREATE OR REPLACE FUNCTION public.payer_achat(_achat_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.achats SET statut = 'paye', updated_at = now()
    WHERE achat_id = _achat_id AND statut = 'recu';
  IF NOT FOUND THEN RAISE EXCEPTION 'Achat introuvable ou statut invalide'; END IF;
END $$;
