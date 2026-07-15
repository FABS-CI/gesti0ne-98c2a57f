
CREATE SCHEMA IF NOT EXISTS e2e_fixtures;

-- Constantes UUID stables réutilisées par tous les tests
CREATE OR REPLACE FUNCTION e2e_fixtures.client_id()  RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT '11111111-1111-1111-1111-111111111111'::uuid $$;
CREATE OR REPLACE FUNCTION e2e_fixtures.facture_id() RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT '22222222-2222-2222-2222-222222222222'::uuid $$;
CREATE OR REPLACE FUNCTION e2e_fixtures.bl_id()      RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT '33333333-3333-3333-3333-333333333333'::uuid $$;
CREATE OR REPLACE FUNCTION e2e_fixtures.colis1_id()  RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT '44444444-4444-4444-4444-444444444444'::uuid $$;
CREATE OR REPLACE FUNCTION e2e_fixtures.colis2_id()  RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT '55555555-5555-5555-5555-555555555555'::uuid $$;

-- Seed idempotent
CREATE OR REPLACE FUNCTION e2e_fixtures.seed()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$
BEGIN
  INSERT INTO public.clients (client_id, reference, nom, actif)
  VALUES (e2e_fixtures.client_id(), 'E2E-CLIENT', 'E2E — Client de test', true)
  ON CONFLICT (client_id) DO UPDATE SET nom = EXCLUDED.nom, actif = true;

  INSERT INTO public.factures (
    facture_id, reference, client_id, client_nom,
    date_facture, montant_total, montant_paye, statut
  )
  VALUES (
    e2e_fixtures.facture_id(), 'E2E-FAC-0001', e2e_fixtures.client_id(),
    'E2E — Client de test', CURRENT_DATE, 10000, 0, 'impayee'
  )
  ON CONFLICT (facture_id) DO UPDATE
    SET montant_total = 10000, montant_paye = 0, statut = 'impayee';

  INSERT INTO public.bons_livraison (
    bl_id, reference, client_id, date_emission, statut, montant_total
  )
  VALUES (
    e2e_fixtures.bl_id(), 'E2E-BL-0001', e2e_fixtures.client_id(),
    CURRENT_DATE, 'a_preparer', 10000
  )
  ON CONFLICT (bl_id) DO UPDATE
    SET statut = 'a_preparer', date_livraison = NULL, montant_total = 10000;

  INSERT INTO public.colis (colis_id, reference, bl_id, statut)
  VALUES
    (e2e_fixtures.colis1_id(), 'E2E-COL-0001', e2e_fixtures.bl_id(), 'en_cours'),
    (e2e_fixtures.colis2_id(), 'E2E-COL-0002', e2e_fixtures.bl_id(), 'en_cours')
  ON CONFLICT (colis_id) DO UPDATE SET statut = 'en_cours', bl_id = EXCLUDED.bl_id;
END;
$$;

-- Reset : ré-applique l'état initial
CREATE OR REPLACE FUNCTION e2e_fixtures.reset()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$
BEGIN
  UPDATE public.bons_livraison
     SET statut = 'a_preparer', date_livraison = NULL
   WHERE bl_id = e2e_fixtures.bl_id();

  UPDATE public.colis SET statut = 'en_cours' WHERE bl_id = e2e_fixtures.bl_id();

  UPDATE public.factures
     SET montant_total = 10000, montant_paye = 0, statut = 'impayee'
   WHERE facture_id = e2e_fixtures.facture_id();

  PERFORM e2e_fixtures.seed();
END;
$$;

-- Pilotage du paiement (le trigger recalcule automatiquement le statut)
CREATE OR REPLACE FUNCTION e2e_fixtures.set_facture_paye(montant numeric)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$
DECLARE v_statut text;
BEGIN
  UPDATE public.factures
     SET montant_paye = montant
   WHERE facture_id = e2e_fixtures.facture_id()
  RETURNING statut INTO v_statut;
  RETURN v_statut;
END;
$$;

CREATE OR REPLACE FUNCTION e2e_fixtures.set_facture_statut(nouveau_statut text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$
DECLARE v_statut text;
BEGIN
  UPDATE public.factures
     SET statut = nouveau_statut
   WHERE facture_id = e2e_fixtures.facture_id()
  RETURNING statut INTO v_statut;
  RETURN v_statut;
END;
$$;

CREATE OR REPLACE FUNCTION e2e_fixtures.set_colis_livre(numero int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$
BEGIN
  IF numero = 1 THEN
    UPDATE public.colis SET statut = 'livre' WHERE colis_id = e2e_fixtures.colis1_id();
  ELSIF numero = 2 THEN
    UPDATE public.colis SET statut = 'livre' WHERE colis_id = e2e_fixtures.colis2_id();
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION e2e_fixtures.get_facture()
RETURNS TABLE(facture_id uuid, statut text, montant_paye numeric, montant_total numeric)
LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$
  SELECT f.facture_id, f.statut, f.montant_paye, f.montant_total
    FROM public.factures f
   WHERE f.facture_id = e2e_fixtures.facture_id();
$$;

CREATE OR REPLACE FUNCTION e2e_fixtures.get_bl()
RETURNS TABLE(bl_id uuid, statut text, date_livraison date)
LANGUAGE sql SECURITY DEFINER SET search_path = public, e2e_fixtures
AS $$
  SELECT b.bl_id, b.statut, b.date_livraison
    FROM public.bons_livraison b
   WHERE b.bl_id = e2e_fixtures.bl_id();
$$;

-- Permissions : les tests e2e tournent sous session Lovable (authenticated)
GRANT USAGE ON SCHEMA e2e_fixtures TO authenticated, service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA e2e_fixtures FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA e2e_fixtures TO authenticated, service_role;

-- Seed initial
SELECT e2e_fixtures.seed();
