-- Séquence de référence des écritures
CREATE SEQUENCE IF NOT EXISTS public.ecriture_ref_seq;

-- En-tête d'écriture comptable
CREATE TABLE public.ecritures_comptables (
  ecriture_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference text NOT NULL DEFAULT ('ECR-' || lpad(nextval('public.ecriture_ref_seq')::text, 5, '0')),
  date_ecriture date NOT NULL DEFAULT CURRENT_DATE,
  journal text NOT NULL DEFAULT 'OD',
  libelle text NOT NULL,
  source_type text,
  source_id uuid,
  lettrage text,
  montant_total numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Lignes d'écriture (partie double)
CREATE TABLE public.ecriture_lignes (
  ligne_id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  ecriture_id uuid NOT NULL REFERENCES public.ecritures_comptables(ecriture_id) ON DELETE CASCADE,
  compte text NOT NULL,
  compte_libelle text NOT NULL,
  debit numeric NOT NULL DEFAULT 0,
  credit numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.ecritures_comptables TO authenticated;
GRANT ALL ON public.ecritures_comptables TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ecriture_lignes TO authenticated;
GRANT ALL ON public.ecriture_lignes TO service_role;

ALTER TABLE public.ecritures_comptables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecriture_lignes ENABLE ROW LEVEL SECURITY;

-- RLS : rôles financiers uniquement
CREATE POLICY "Finance peut tout sur ecritures" ON public.ecritures_comptables
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]));

CREATE POLICY "Finance peut tout sur ecriture_lignes" ON public.ecriture_lignes
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]));

CREATE INDEX idx_ecriture_lignes_ecriture_id ON public.ecriture_lignes(ecriture_id);
CREATE INDEX idx_ecritures_source ON public.ecritures_comptables(source_type, source_id);
CREATE INDEX idx_ecritures_lettrage ON public.ecritures_comptables(lettrage);

CREATE TRIGGER trg_ecritures_updated_at
  BEFORE UPDATE ON public.ecritures_comptables
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Génération auto : écriture de vente à la création d'une facture
CREATE OR REPLACE FUNCTION public.generate_ecriture_facture()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ecriture_id uuid;
BEGIN
  INSERT INTO public.ecritures_comptables (date_ecriture, journal, libelle, source_type, source_id, lettrage, montant_total)
  VALUES (NEW.date_facture, 'VT', 'Facture ' || NEW.reference || COALESCE(' - ' || NEW.client_nom, ''), 'facture', NEW.facture_id, NEW.reference, NEW.montant_total)
  RETURNING ecriture_id INTO v_ecriture_id;

  INSERT INTO public.ecriture_lignes (ecriture_id, compte, compte_libelle, debit, credit) VALUES
    (v_ecriture_id, '411', 'Clients', NEW.montant_total, 0),
    (v_ecriture_id, '701', 'Ventes de marchandises', 0, NEW.montant_total);

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_facture_ecriture
  AFTER INSERT ON public.factures
  FOR EACH ROW EXECUTE FUNCTION public.generate_ecriture_facture();

-- Génération auto : écriture d'encaissement à l'enregistrement d'un paiement validé
CREATE OR REPLACE FUNCTION public.generate_ecriture_paiement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ecriture_id uuid;
  v_compte text;
  v_compte_lib text;
  v_lettrage text;
BEGIN
  IF NEW.statut <> 'valide' THEN
    RETURN NEW;
  END IF;

  IF NEW.mode_paiement = 'especes' THEN
    v_compte := '571'; v_compte_lib := 'Caisse';
  ELSE
    v_compte := '521'; v_compte_lib := 'Banque';
  END IF;

  SELECT reference INTO v_lettrage FROM public.factures WHERE facture_id = NEW.facture_id;

  INSERT INTO public.ecritures_comptables (date_ecriture, journal, libelle, source_type, source_id, lettrage, montant_total)
  VALUES (NEW.date_paiement,
          CASE WHEN NEW.mode_paiement = 'especes' THEN 'CA' ELSE 'BQ' END,
          'Encaissement ' || NEW.reference || COALESCE(' - ' || NEW.client_nom, ''),
          'paiement', NEW.paiement_id, v_lettrage, NEW.montant)
  RETURNING ecriture_id INTO v_ecriture_id;

  INSERT INTO public.ecriture_lignes (ecriture_id, compte, compte_libelle, debit, credit) VALUES
    (v_ecriture_id, v_compte, v_compte_lib, NEW.montant, 0),
    (v_ecriture_id, '411', 'Clients', 0, NEW.montant);

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_paiement_ecriture
  AFTER INSERT ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.generate_ecriture_paiement();