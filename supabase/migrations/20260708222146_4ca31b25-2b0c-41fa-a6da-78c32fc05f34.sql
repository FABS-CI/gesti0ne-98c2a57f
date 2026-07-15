
-- ============================================================
-- A5 : sync colis.statut ↔ statut_logistique
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_colis_sync_statut()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NEW.statut_logistique IN ('livre','remis_client') THEN
    NEW.statut := 'livre';
  ELSIF NEW.statut_logistique IN ('en_cours_livraison','arrive_client','depose_gare','en_cours_expedition','arrive_ville') THEN
    IF NEW.statut IS DISTINCT FROM 'livre' THEN NEW.statut := 'en_livraison'; END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_colis_sync_statut ON public.colis;
CREATE TRIGGER trg_colis_sync_statut
  BEFORE INSERT OR UPDATE OF statut_logistique ON public.colis
  FOR EACH ROW EXECUTE FUNCTION public.trg_colis_sync_statut();

-- Backfill : aligner l'existant
UPDATE public.colis
   SET statut = 'livre'
 WHERE statut_logistique IN ('livre','remis_client')
   AND statut IS DISTINCT FROM 'livre';

-- ============================================================
-- Correctif A5bis : trigger BL livré doit lire statut_logistique
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_bl_livre_when_all_colis_livres()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_bl uuid := NEW.bl_id; v_total int; v_livres int;
BEGIN
  IF v_bl IS NULL THEN RETURN NEW; END IF;
  IF NEW.statut_logistique IS DISTINCT FROM 'livre'
     AND NEW.statut_logistique IS DISTINCT FROM 'remis_client' THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE statut_logistique IN ('livre','remis_client'))
    INTO v_total, v_livres
    FROM public.colis WHERE bl_id = v_bl;

  IF v_total > 0 AND v_livres = v_total THEN
    UPDATE public.bons_livraison
       SET statut = 'livre',
           date_livraison = COALESCE(date_livraison, CURRENT_DATE)
     WHERE bl_id = v_bl AND statut IS DISTINCT FROM 'livre';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_bl_livre_auto ON public.colis;
CREATE TRIGGER trg_bl_livre_auto
  AFTER INSERT OR UPDATE OF statut, statut_logistique, bl_id ON public.colis
  FOR EACH ROW EXECUTE FUNCTION public.set_bl_livre_when_all_colis_livres();

-- ============================================================
-- A6/A7/A8 : propagation BL livré → commande + livsuivi + livraison_commande
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_bl_livre_propage()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_liv uuid;
BEGIN
  IF NEW.statut <> 'livre' OR OLD.statut = 'livre' OR NEW.commande_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Commande → livree
  UPDATE public.commandes
     SET statut = 'livree', updated_at = now()
   WHERE commande_id = NEW.commande_id
     AND statut IS DISTINCT FROM 'livree';

  -- livsuivi_commandes → livree + clôture
  UPDATE public.livsuivi_commandes
     SET statut = 'livree'::public.livsuivi_statut,
         cloturee = TRUE,
         derniere_maj = now(),
         updated_at = now()
   WHERE commande_id = NEW.commande_id
     AND (statut IS DISTINCT FROM 'livree'::public.livsuivi_statut OR cloturee IS DISTINCT FROM TRUE);

  -- livraisons_commande → livree
  SELECT livraison_id INTO v_liv
    FROM public.livraisons_commande WHERE commande_id = NEW.commande_id;
  IF v_liv IS NOT NULL THEN
    UPDATE public.livraisons_commande
       SET statut = 'livree'::public.statut_livraison_cmd,
           progression_pct = 100,
           derniere_maj = now(),
           updated_at = now()
     WHERE livraison_id = v_liv
       AND statut IS DISTINCT FROM 'livree'::public.statut_livraison_cmd;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_bl_livre_propage ON public.bons_livraison;
CREATE TRIGGER trg_bl_livre_propage
  AFTER UPDATE OF statut ON public.bons_livraison
  FOR EACH ROW EXECUTE FUNCTION public.trg_bl_livre_propage();

-- ============================================================
-- A9 : RPC generer_facture idempotent (renvoie l'existante sinon crée)
-- ============================================================
CREATE OR REPLACE FUNCTION public.generer_facture(_commande_id uuid)
RETURNS public.factures LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_f public.factures; v_cmd public.commandes; v_ref text; v_ex uuid;
BEGIN
  -- Idempotence : renvoyer une facture existante si déjà générée
  SELECT * INTO v_f FROM public.factures
   WHERE commande_id = _commande_id
   ORDER BY created_at ASC LIMIT 1;
  IF FOUND THEN RETURN v_f; END IF;

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id = _commande_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Commande introuvable %', _commande_id; END IF;

  v_ref := 'FAC-' || to_char(now(),'YYYYMMDD') || '-' || substr(gen_random_uuid()::text,1,6);
  SELECT exercice_id INTO v_ex FROM public.exercices
   WHERE CURRENT_DATE BETWEEN date_debut AND date_fin AND statut = 'ouvert'
   LIMIT 1;

  INSERT INTO public.factures(
    reference, client_id, client_nom, commande_id,
    date_facture, date_echeance, montant_total, montant_paye, statut, exercice_id
  ) VALUES (
    v_ref, v_cmd.client_id, v_cmd.client_nom, _commande_id,
    CURRENT_DATE, CURRENT_DATE + 30, COALESCE(v_cmd.net_a_payer, v_cmd.montant_total, 0),
    0, 'impayee', v_ex
  ) RETURNING * INTO v_f;

  RETURN v_f;
END $$;

GRANT EXECUTE ON FUNCTION public.generer_facture(uuid) TO authenticated;
