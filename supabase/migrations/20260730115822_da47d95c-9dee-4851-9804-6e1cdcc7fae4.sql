ALTER TABLE public.retour_lignes
  ADD COLUMN IF NOT EXISTS remise_pct numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS etat_produit text NOT NULL DEFAULT 'revendable',
  ADD COLUMN IF NOT EXISTS montant_brut numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remise_montant numeric NOT NULL DEFAULT 0;

DO $$ BEGIN
  ALTER TABLE public.retour_lignes
    ADD CONSTRAINT retour_lignes_etat_produit_check
    CHECK (etat_produit IN ('revendable','endommage','perdu'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE public.retour_lignes DROP CONSTRAINT IF EXISTS retour_lignes_etat_check;
ALTER TABLE public.retour_lignes
  ADD CONSTRAINT retour_lignes_etat_check
  CHECK (etat_reception IS NULL OR etat_reception IN ('conforme','endommage','manquant','refuse'));

CREATE OR REPLACE FUNCTION public._retour_ligne_calc()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_qte numeric;
BEGIN
  NEW.quantite := COALESCE(NEW.quantite, NEW.quantite_demandee, 0);
  NEW.quantite_demandee := COALESCE(NEW.quantite_demandee, NEW.quantite);
  NEW.remise_pct := LEAST(GREATEST(COALESCE(NEW.remise_pct,0),0),100);
  NEW.prix_unitaire := COALESCE(NEW.prix_unitaire,0);
  NEW.etat_produit := COALESCE(NEW.etat_produit,'revendable');
  v_qte := COALESCE(NEW.quantite_recue, NEW.quantite, 0);
  NEW.montant_brut   := ROUND(v_qte * NEW.prix_unitaire);
  NEW.remise_montant := ROUND(NEW.montant_brut * NEW.remise_pct / 100.0);
  NEW.total_ligne    := NEW.montant_brut - NEW.remise_montant;
  NEW.updated_at     := now();
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_retour_ligne_calc ON public.retour_lignes;
CREATE TRIGGER trg_retour_ligne_calc
  BEFORE INSERT OR UPDATE ON public.retour_lignes
  FOR EACH ROW EXECUTE FUNCTION public._retour_ligne_calc();

CREATE OR REPLACE FUNCTION public._retour_recalc_totaux()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  v_id := COALESCE(NEW.retour_id, OLD.retour_id);
  UPDATE public.retours r SET
    nb_produits    = agg.nb,
    total_quantite = agg.qte,
    montant        = agg.montant,
    updated_at     = now()
  FROM (
    SELECT COUNT(*)::int AS nb,
           COALESCE(SUM(COALESCE(quantite_recue, quantite, 0)),0) AS qte,
           COALESCE(SUM(total_ligne),0) AS montant
    FROM public.retour_lignes WHERE retour_id = v_id
  ) agg
  WHERE r.retour_id = v_id;
  RETURN NULL;
END; $$;

DROP TRIGGER IF EXISTS trg_retour_recalc_totaux ON public.retour_lignes;
CREATE TRIGGER trg_retour_recalc_totaux
  AFTER INSERT OR UPDATE OR DELETE ON public.retour_lignes
  FOR EACH ROW EXECUTE FUNCTION public._retour_recalc_totaux();

UPDATE public.retour_lignes rl
SET prix_unitaire = cl.prix_unitaire,
    remise_pct    = COALESCE(cl.remise_pct, 0)
FROM public.retours r
JOIN public.factures f ON f.facture_id = r.facture_id
JOIN public.commande_lignes cl ON cl.commande_id = f.commande_id
WHERE rl.retour_id = r.retour_id
  AND cl.produit_id = rl.produit_id
  AND COALESCE(rl.prix_unitaire,0) = 0
  AND COALESCE(cl.prix_unitaire,0) > 0;

UPDATE public.retour_lignes rl
SET prix_unitaire = p.prix_vente
FROM public.produits p
WHERE p.produit_id = rl.produit_id
  AND COALESCE(rl.prix_unitaire,0) = 0
  AND COALESCE(p.prix_vente,0) > 0;

UPDATE public.retour_lignes SET updated_at = now();

DO $$ BEGIN
  ALTER TABLE public.retour_lignes
    ADD CONSTRAINT retour_lignes_quantite_positive CHECK (quantite > 0) NOT VALID;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;