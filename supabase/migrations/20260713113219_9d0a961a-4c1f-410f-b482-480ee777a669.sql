
CREATE OR REPLACE FUNCTION public.compute_total_ligne_simple()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  NEW.total_ligne := ROUND(
    COALESCE(NEW.quantite,0)::numeric * COALESCE(NEW.prix_unitaire,0)::numeric, 2);
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.compute_total_ligne_commande()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  NEW.montant_remise := ROUND(
    COALESCE(NEW.quantite,0)::numeric * COALESCE(NEW.prix_unitaire,0)::numeric
    * COALESCE(NEW.remise_pct,0) / 100.0, 2);
  NEW.total_ht_ligne := ROUND(
    COALESCE(NEW.quantite,0)::numeric * COALESCE(NEW.prix_unitaire,0)::numeric
    * (1 - COALESCE(NEW.remise_pct,0) / 100.0), 2);
  NEW.total_ligne := NEW.total_ht_ligne;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_compute_total_ligne ON public.commande_lignes;
CREATE TRIGGER trg_compute_total_ligne BEFORE INSERT OR UPDATE ON public.commande_lignes
  FOR EACH ROW EXECUTE FUNCTION public.compute_total_ligne_commande();

DROP TRIGGER IF EXISTS trg_compute_total_ligne ON public.proforma_lignes;
CREATE TRIGGER trg_compute_total_ligne BEFORE INSERT OR UPDATE ON public.proforma_lignes
  FOR EACH ROW EXECUTE FUNCTION public.compute_total_ligne_simple();

DROP TRIGGER IF EXISTS trg_compute_total_ligne ON public.achat_lignes;
CREATE TRIGGER trg_compute_total_ligne BEFORE INSERT OR UPDATE ON public.achat_lignes
  FOR EACH ROW EXECUTE FUNCTION public.compute_total_ligne_simple();

DROP TRIGGER IF EXISTS trg_compute_total_ligne ON public.retour_lignes;
CREATE TRIGGER trg_compute_total_ligne BEFORE INSERT OR UPDATE ON public.retour_lignes
  FOR EACH ROW EXECUTE FUNCTION public.compute_total_ligne_simple();

CREATE OR REPLACE FUNCTION public.dashboard_overview_stats(
  _date_debut date DEFAULT NULL, _date_fin date DEFAULT NULL
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH bornes AS (
    SELECT COALESCE(_date_debut,(now()-interval '30 days')::date) AS d1,
           COALESCE(_date_fin, now()::date) AS d2
  ),
  f AS (SELECT COUNT(*) nb, COALESCE(SUM(montant_total),0) total FROM public.factures, bornes WHERE date_facture BETWEEN bornes.d1 AND bornes.d2),
  p AS (SELECT COUNT(*) nb, COALESCE(SUM(montant),0) total FROM public.paiements, bornes WHERE date_paiement BETWEEN bornes.d1 AND bornes.d2),
  c AS (SELECT COUNT(*) nb, COALESCE(SUM(montant_total),0) total FROM public.commandes, bornes WHERE date_commande BETWEEN bornes.d1 AND bornes.d2),
  a AS (SELECT COUNT(*) nb, COALESCE(SUM(montant),0) total FROM public.achats, bornes WHERE date_achat BETWEEN bornes.d1 AND bornes.d2)
  SELECT jsonb_build_object(
    'factures',  jsonb_build_object('nb',f.nb,'total',f.total),
    'paiements', jsonb_build_object('nb',p.nb,'total',p.total),
    'commandes', jsonb_build_object('nb',c.nb,'total',c.total),
    'achats',    jsonb_build_object('nb',a.nb,'total',a.total)
  ) FROM f,p,c,a;
$$;

REVOKE ALL ON FUNCTION public.dashboard_overview_stats(date, date) FROM public;
GRANT EXECUTE ON FUNCTION public.dashboard_overview_stats(date, date) TO authenticated;
