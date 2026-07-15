
CREATE OR REPLACE FUNCTION public.e2e_seed()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$ SELECT e2e_fixtures.seed(); $$;

CREATE OR REPLACE FUNCTION public.e2e_reset()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$ SELECT e2e_fixtures.reset(); $$;

CREATE OR REPLACE FUNCTION public.e2e_set_facture_paye(montant numeric)
RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$ SELECT e2e_fixtures.set_facture_paye(montant); $$;

CREATE OR REPLACE FUNCTION public.e2e_set_facture_statut(nouveau_statut text)
RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$ SELECT e2e_fixtures.set_facture_statut(nouveau_statut); $$;

CREATE OR REPLACE FUNCTION public.e2e_set_colis_livre(numero int)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$ SELECT e2e_fixtures.set_colis_livre(numero); $$;

CREATE OR REPLACE FUNCTION public.e2e_get_facture()
RETURNS TABLE(facture_id uuid, statut text, montant_paye numeric, montant_total numeric)
LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$ SELECT * FROM e2e_fixtures.get_facture(); $$;

CREATE OR REPLACE FUNCTION public.e2e_get_bl()
RETURNS TABLE(bl_id uuid, statut text, date_livraison date)
LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$ SELECT * FROM e2e_fixtures.get_bl(); $$;

REVOKE ALL ON FUNCTION public.e2e_seed(), public.e2e_reset(),
  public.e2e_set_facture_paye(numeric), public.e2e_set_facture_statut(text),
  public.e2e_set_colis_livre(int), public.e2e_get_facture(), public.e2e_get_bl()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.e2e_seed(), public.e2e_reset(),
  public.e2e_set_facture_paye(numeric), public.e2e_set_facture_statut(text),
  public.e2e_set_colis_livre(int), public.e2e_get_facture(), public.e2e_get_bl()
  TO authenticated, service_role;
