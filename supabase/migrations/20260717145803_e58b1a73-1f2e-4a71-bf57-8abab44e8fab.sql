
INSERT INTO public.journaux_comptables (code, libelle, type) VALUES
  ('VTE', 'Journal des ventes',       'vente'),
  ('ACH', 'Journal des achats',       'achat'),
  ('BAN', 'Journal de banque',        'tresorerie'),
  ('CAI', 'Journal de caisse',        'tresorerie'),
  ('OD',  'Opérations diverses',      'od')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.plan_comptable (numero, libelle, classe, type)
SELECT * FROM (VALUES
  ('411', 'Clients',                  4, 'actif'),
  ('401', 'Fournisseurs',             4, 'passif'),
  ('701', 'Ventes de marchandises',   7, 'produit'),
  ('601', 'Achats de marchandises',   6, 'charge'),
  ('571', 'Caisse',                   5, 'actif'),
  ('521', 'Banque',                   5, 'actif'),
  ('585', 'Virements internes / Mobile Money', 5, 'actif')
) AS v(numero, libelle, classe, type)
WHERE NOT EXISTS (SELECT 1 FROM public.plan_comptable pc WHERE pc.numero = v.numero);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ecritures_piece_ref
  ON public.ecritures_comptables (piece_ref)
  WHERE piece_ref IS NOT NULL;

CREATE OR REPLACE FUNCTION public._journal_id(_code text)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT journal_id FROM public.journaux_comptables WHERE code = _code LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._compte_mode_paiement(_mode text)
RETURNS TABLE(compte text, journal text)
LANGUAGE sql IMMUTABLE AS $$
  SELECT
    CASE lower(coalesce(_mode,'espece'))
      WHEN 'espece' THEN '571' WHEN 'especes' THEN '571' WHEN 'cash' THEN '571'
      WHEN 'cheque' THEN '521' WHEN 'virement' THEN '521' WHEN 'carte' THEN '521'
      WHEN 'mobile_money' THEN '585' WHEN 'wave' THEN '585'
      WHEN 'orange_money' THEN '585' WHEN 'mtn' THEN '585' WHEN 'moov' THEN '585'
      ELSE '521'
    END AS compte,
    CASE lower(coalesce(_mode,'espece'))
      WHEN 'espece' THEN 'CAI' WHEN 'especes' THEN 'CAI' WHEN 'cash' THEN 'CAI'
      ELSE 'BAN'
    END AS journal;
$$;

CREATE OR REPLACE FUNCTION public.generate_ecriture_facture(_facture_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE f RECORD; v_piece text; v_ecriture_id uuid; v_journal uuid;
BEGIN
  SELECT * INTO f FROM public.factures WHERE facture_id = _facture_id;
  IF NOT FOUND OR f.statut = 'annulee' OR coalesce(f.montant_total,0) = 0 THEN RETURN NULL; END IF;
  v_piece := 'FACT:' || f.facture_id::text;
  SELECT ecriture_id INTO v_ecriture_id FROM public.ecritures_comptables WHERE piece_ref = v_piece;
  IF v_ecriture_id IS NOT NULL THEN RETURN v_ecriture_id; END IF;
  v_journal := public._journal_id('VTE');
  INSERT INTO public.ecritures_comptables
    (reference, journal_id, journal, date_ecriture, libelle, montant, statut, piece_ref, exercice_id)
  VALUES (f.reference, v_journal, 'VTE', f.date_facture,
     'Facture ' || f.reference || ' - ' || coalesce(f.client_nom,''),
     f.montant_total, 'valide', v_piece, f.exercice_id)
  RETURNING ecriture_id INTO v_ecriture_id;
  INSERT INTO public.ecriture_lignes (ecriture_id, numero_compte, compte, compte_libelle, libelle, debit, credit) VALUES
    (v_ecriture_id, '411', '411', 'Clients',                'Créance ' || coalesce(f.client_nom,''), f.montant_total, 0),
    (v_ecriture_id, '701', '701', 'Ventes de marchandises', 'Vente ' || f.reference,                 0, f.montant_total);
  RETURN v_ecriture_id;
END; $$;

CREATE OR REPLACE FUNCTION public.generate_ecriture_paiement(_paiement_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE p RECORD; f RECORD; m RECORD; v_piece text; v_ecriture_id uuid; v_journal uuid; v_libelle text;
BEGIN
  SELECT * INTO p FROM public.paiements WHERE paiement_id = _paiement_id;
  IF NOT FOUND OR p.statut <> 'valide' OR coalesce(p.montant,0) = 0 THEN RETURN NULL; END IF;
  v_piece := 'PAI:' || p.paiement_id::text;
  SELECT ecriture_id INTO v_ecriture_id FROM public.ecritures_comptables WHERE piece_ref = v_piece;
  IF v_ecriture_id IS NOT NULL THEN RETURN v_ecriture_id; END IF;
  SELECT * INTO m FROM public._compte_mode_paiement(p.mode_paiement);
  v_journal := public._journal_id(m.journal);
  IF p.facture_id IS NOT NULL THEN
    SELECT reference, client_nom INTO f FROM public.factures WHERE facture_id = p.facture_id;
    v_libelle := 'Règlement facture ' || coalesce(f.reference,'') || ' - ' || coalesce(f.client_nom, p.client_nom, '');
  ELSE
    v_libelle := 'Encaissement ' || coalesce(p.client_nom,'') || ' (' || p.mode_paiement || ')';
  END IF;
  INSERT INTO public.ecritures_comptables
    (reference, journal_id, journal, date_ecriture, libelle, montant, statut, piece_ref, exercice_id)
  VALUES (p.reference, v_journal, m.journal, p.date_paiement, v_libelle, p.montant, 'valide', v_piece, p.exercice_id)
  RETURNING ecriture_id INTO v_ecriture_id;
  INSERT INTO public.ecriture_lignes (ecriture_id, numero_compte, compte, compte_libelle, libelle, debit, credit) VALUES
    (v_ecriture_id, m.compte, m.compte,
       CASE m.compte WHEN '571' THEN 'Caisse' WHEN '521' THEN 'Banque' WHEN '585' THEN 'Mobile Money' ELSE 'Trésorerie' END,
       v_libelle, p.montant, 0),
    (v_ecriture_id, '411', '411', 'Clients', 'Lettrage ' || coalesce(p.client_nom,''), 0, p.montant);
  RETURN v_ecriture_id;
END; $$;

CREATE OR REPLACE FUNCTION public.generate_ecriture_achat(_achat_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE a RECORD; v_piece text; v_ecriture_id uuid; v_journal uuid;
BEGIN
  SELECT * INTO a FROM public.achats WHERE achat_id = _achat_id;
  IF NOT FOUND OR a.statut NOT IN ('confirme','receptionne','paye') OR coalesce(a.montant,0) = 0 THEN RETURN NULL; END IF;
  v_piece := 'ACH:' || a.achat_id::text;
  SELECT ecriture_id INTO v_ecriture_id FROM public.ecritures_comptables WHERE piece_ref = v_piece;
  IF v_ecriture_id IS NOT NULL THEN RETURN v_ecriture_id; END IF;
  v_journal := public._journal_id('ACH');
  INSERT INTO public.ecritures_comptables
    (reference, journal_id, journal, date_ecriture, libelle, montant, statut, piece_ref, exercice_id)
  VALUES (a.reference, v_journal, 'ACH', a.date_achat,
     'Achat ' || a.reference || ' - ' || coalesce(a.fournisseur_nom,''),
     a.montant, 'valide', v_piece, a.exercice_id)
  RETURNING ecriture_id INTO v_ecriture_id;
  INSERT INTO public.ecriture_lignes (ecriture_id, numero_compte, compte, compte_libelle, libelle, debit, credit) VALUES
    (v_ecriture_id, '601', '601', 'Achats de marchandises', 'Achat ' || a.reference,           a.montant, 0),
    (v_ecriture_id, '401', '401', 'Fournisseurs',           'Dette ' || coalesce(a.fournisseur_nom,''), 0, a.montant);
  RETURN v_ecriture_id;
END; $$;

CREATE OR REPLACE FUNCTION public._delete_ecriture_piece(_piece text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM public.ecritures_comptables WHERE piece_ref = _piece;
$$;

-- TRIGGERS
CREATE OR REPLACE FUNCTION public._trg_facture_ecriture()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public._delete_ecriture_piece('FACT:' || OLD.facture_id::text);
    RETURN OLD;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.statut <> 'annulee' THEN PERFORM public.generate_ecriture_facture(NEW.facture_id); END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.statut = 'annulee' AND coalesce(OLD.statut,'') <> 'annulee' THEN
      PERFORM public._delete_ecriture_piece('FACT:' || NEW.facture_id::text);
    ELSIF NEW.statut <> 'annulee' AND coalesce(OLD.statut,'') = 'annulee' THEN
      PERFORM public.generate_ecriture_facture(NEW.facture_id);
    ELSIF NEW.montant_total <> OLD.montant_total AND NEW.statut <> 'annulee' THEN
      PERFORM public._delete_ecriture_piece('FACT:' || NEW.facture_id::text);
      PERFORM public.generate_ecriture_facture(NEW.facture_id);
    END IF;
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_factures_ecriture ON public.factures;
CREATE TRIGGER trg_factures_ecriture AFTER INSERT OR UPDATE OR DELETE ON public.factures
  FOR EACH ROW EXECUTE FUNCTION public._trg_facture_ecriture();

CREATE OR REPLACE FUNCTION public._trg_paiement_ecriture()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public._delete_ecriture_piece('PAI:' || OLD.paiement_id::text);
    RETURN OLD;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.statut = 'valide' THEN PERFORM public.generate_ecriture_paiement(NEW.paiement_id); END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.statut = 'valide' AND coalesce(OLD.statut,'') <> 'valide' THEN
      PERFORM public.generate_ecriture_paiement(NEW.paiement_id);
    ELSIF NEW.statut <> 'valide' AND coalesce(OLD.statut,'') = 'valide' THEN
      PERFORM public._delete_ecriture_piece('PAI:' || NEW.paiement_id::text);
    END IF;
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_paiements_ecriture ON public.paiements;
CREATE TRIGGER trg_paiements_ecriture AFTER INSERT OR UPDATE OR DELETE ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public._trg_paiement_ecriture();

CREATE OR REPLACE FUNCTION public._trg_achat_ecriture()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public._delete_ecriture_piece('ACH:' || OLD.achat_id::text);
    RETURN OLD;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.statut IN ('confirme','receptionne','paye') THEN PERFORM public.generate_ecriture_achat(NEW.achat_id); END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.statut IN ('confirme','receptionne','paye') AND coalesce(OLD.statut,'') NOT IN ('confirme','receptionne','paye') THEN
      PERFORM public.generate_ecriture_achat(NEW.achat_id);
    ELSIF NEW.statut NOT IN ('confirme','receptionne','paye') AND coalesce(OLD.statut,'') IN ('confirme','receptionne','paye') THEN
      PERFORM public._delete_ecriture_piece('ACH:' || NEW.achat_id::text);
    ELSIF NEW.montant <> OLD.montant AND NEW.statut IN ('confirme','receptionne','paye') THEN
      PERFORM public._delete_ecriture_piece('ACH:' || NEW.achat_id::text);
      PERFORM public.generate_ecriture_achat(NEW.achat_id);
    END IF;
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_achats_ecriture ON public.achats;
CREATE TRIGGER trg_achats_ecriture AFTER INSERT OR UPDATE OR DELETE ON public.achats
  FOR EACH ROW EXECUTE FUNCTION public._trg_achat_ecriture();

-- BACKFILL
DO $backfill$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT facture_id FROM public.factures WHERE statut <> 'annulee' LOOP
    PERFORM public.generate_ecriture_facture(r.facture_id);
  END LOOP;
  FOR r IN SELECT paiement_id FROM public.paiements WHERE statut = 'valide' LOOP
    PERFORM public.generate_ecriture_paiement(r.paiement_id);
  END LOOP;
  FOR r IN SELECT achat_id FROM public.achats WHERE statut IN ('confirme','receptionne','paye') LOOP
    PERFORM public.generate_ecriture_achat(r.achat_id);
  END LOOP;
END; $backfill$;
