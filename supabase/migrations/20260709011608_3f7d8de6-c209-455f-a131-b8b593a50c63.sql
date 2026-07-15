-- 1) Séquence + table avoirs -------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.avoirs_ref_seq START 1;

CREATE TABLE IF NOT EXISTS public.avoirs (
  avoir_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference       text NOT NULL UNIQUE
                   DEFAULT ('AV-' || to_char(now(),'YYYY') || '-' ||
                            lpad(nextval('public.avoirs_ref_seq')::text, 5, '0')),
  retour_id       uuid REFERENCES public.retours(retour_id) ON DELETE SET NULL,
  br_id           uuid REFERENCES public.bons_retour(br_id) ON DELETE SET NULL,
  facture_id      uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  client_id       uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  client_nom      text,
  date_emission   date NOT NULL DEFAULT CURRENT_DATE,
  montant         numeric(14,2) NOT NULL DEFAULT 0 CHECK (montant >= 0),
  statut          text NOT NULL DEFAULT 'emis'
                   CHECK (statut IN ('emis','impute','rembourse','annule')),
  mode_reglement  text,
  date_reglement  date,
  facture_imputee_id uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  paiement_id     uuid REFERENCES public.paiements(paiement_id) ON DELETE SET NULL,
  notes           text,
  exercice_id     uuid NOT NULL DEFAULT public.exercice_actif_id()
                   REFERENCES public.exercices(exercice_id) ON DELETE RESTRICT,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_avoirs_retour   ON public.avoirs(retour_id);
CREATE INDEX IF NOT EXISTS idx_avoirs_facture  ON public.avoirs(facture_id);
CREATE INDEX IF NOT EXISTS idx_avoirs_client   ON public.avoirs(client_id);
CREATE INDEX IF NOT EXISTS idx_avoirs_statut   ON public.avoirs(statut);
CREATE INDEX IF NOT EXISTS idx_avoirs_exercice ON public.avoirs(exercice_id);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_avoirs_retour ON public.avoirs(retour_id) WHERE retour_id IS NOT NULL;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.avoirs TO authenticated;
GRANT ALL ON public.avoirs TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.avoirs_ref_seq TO authenticated;
GRANT ALL ON SEQUENCE public.avoirs_ref_seq TO service_role;

ALTER TABLE public.avoirs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff read avoirs" ON public.avoirs;
CREATE POLICY "staff read avoirs" ON public.avoirs
  FOR SELECT TO authenticated
  USING ((SELECT public.is_staff((SELECT auth.uid()))));

DROP POLICY IF EXISTS "staff write avoirs" ON public.avoirs;
CREATE POLICY "staff write avoirs" ON public.avoirs
  FOR ALL TO authenticated
  USING ((SELECT public.is_staff((SELECT auth.uid()))))
  WITH CHECK ((SELECT public.is_staff((SELECT auth.uid()))));

CREATE TRIGGER trg_avoirs_updated_at
  BEFORE UPDATE ON public.avoirs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_avoirs_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.avoirs
  FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

-- 2) Trigger : retour accepté avec facture -> BR + Avoir (idempotent) --------
CREATE OR REPLACE FUNCTION public.trg_retour_generer_br_avoir()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_br_id uuid;
  v_avoir_id uuid;
BEGIN
  IF NEW.statut IS DISTINCT FROM 'accepte' THEN RETURN NEW; END IF;
  IF NEW.facture_id IS NULL THEN RETURN NEW; END IF;

  -- Bon de retour (idempotent : 1 BR par (facture, retour))
  SELECT br_id INTO v_br_id
    FROM public.bons_retour
   WHERE facture_id = NEW.facture_id
     AND notes = 'retour:' || NEW.retour_id::text
   LIMIT 1;

  IF v_br_id IS NULL THEN
    INSERT INTO public.bons_retour(client_id, facture_id, date_retour, motif, statut, montant, notes)
    VALUES(NEW.client_id, NEW.facture_id, NEW.date_retour,
           COALESCE(NEW.motif,'Retour client'), 'valide',
           COALESCE(NEW.montant,0),
           'retour:' || NEW.retour_id::text)
    RETURNING br_id INTO v_br_id;
  END IF;

  -- Avoir (idempotent via uniq_avoirs_retour)
  SELECT avoir_id INTO v_avoir_id
    FROM public.avoirs WHERE retour_id = NEW.retour_id LIMIT 1;

  IF v_avoir_id IS NULL THEN
    INSERT INTO public.avoirs(retour_id, br_id, facture_id, client_id, client_nom,
      date_emission, montant, statut, notes)
    VALUES(NEW.retour_id, v_br_id, NEW.facture_id, NEW.client_id, NEW.client_nom,
           COALESCE(NEW.date_retour, CURRENT_DATE),
           COALESCE(NEW.montant,0), 'emis',
           'Auto-généré depuis retour ' || COALESCE(NEW.numero, NEW.reference));
  ELSE
    UPDATE public.avoirs
       SET br_id = COALESCE(br_id, v_br_id),
           montant = COALESCE(NEW.montant, montant),
           updated_at = now()
     WHERE avoir_id = v_avoir_id AND statut = 'emis';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_retour_generer_br_avoir ON public.retours;
CREATE TRIGGER trg_retour_generer_br_avoir
  AFTER INSERT OR UPDATE OF statut, montant, facture_id ON public.retours
  FOR EACH ROW EXECUTE FUNCTION public.trg_retour_generer_br_avoir();

-- 3) RPC : rembourser un avoir -------------------------------------------------
CREATE OR REPLACE FUNCTION public.rembourser_avoir(
  _avoir_id uuid,
  _mode text DEFAULT 'especes',
  _date date DEFAULT CURRENT_DATE
)
RETURNS public.avoirs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE r public.avoirs;
BEGIN
  IF NOT public.is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Accès refusé' USING ERRCODE='42501';
  END IF;

  UPDATE public.avoirs
     SET statut = 'rembourse',
         mode_reglement = _mode,
         date_reglement = _date,
         updated_at = now()
   WHERE avoir_id = _avoir_id
     AND statut = 'emis'
  RETURNING * INTO r;

  IF r.avoir_id IS NULL THEN
    RAISE EXCEPTION 'Avoir introuvable ou déjà traité' USING ERRCODE='P0010';
  END IF;
  RETURN r;
END $$;

GRANT EXECUTE ON FUNCTION public.rembourser_avoir(uuid, text, date) TO authenticated;

-- 4) RPC : imputer un avoir sur une autre facture du même client --------------
CREATE OR REPLACE FUNCTION public.imputer_avoir_sur_facture(
  _avoir_id uuid,
  _facture_id uuid
)
RETURNS public.avoirs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  a public.avoirs;
  v_client uuid;
  v_reste numeric;
  v_pid uuid;
BEGIN
  IF NOT public.is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'Accès refusé' USING ERRCODE='42501';
  END IF;

  SELECT * INTO a FROM public.avoirs WHERE avoir_id = _avoir_id FOR UPDATE;
  IF a.avoir_id IS NULL THEN
    RAISE EXCEPTION 'Avoir introuvable' USING ERRCODE='P0011';
  END IF;
  IF a.statut <> 'emis' THEN
    RAISE EXCEPTION 'Avoir non imputable (statut=%)', a.statut USING ERRCODE='P0012';
  END IF;

  SELECT client_id INTO v_client FROM public.factures WHERE facture_id = _facture_id;
  IF v_client IS NULL OR v_client IS DISTINCT FROM a.client_id THEN
    RAISE EXCEPTION 'La facture cible doit appartenir au même client' USING ERRCODE='P0013';
  END IF;

  SELECT (montant_total - montant_paye) INTO v_reste
    FROM public.factures WHERE facture_id = _facture_id FOR UPDATE;
  IF v_reste < a.montant THEN
    RAISE EXCEPTION 'Reste à payer (%) inférieur au montant de l''avoir (%)', v_reste, a.montant
      USING ERRCODE='P0014';
  END IF;

  INSERT INTO public.paiements(facture_id, client_nom, date_paiement, montant, mode_paiement, statut, notes, cree_par)
  VALUES(_facture_id, a.client_nom, CURRENT_DATE, a.montant, 'avoir', 'valide',
         'Imputation avoir ' || a.reference, auth.uid())
  RETURNING paiement_id INTO v_pid;

  UPDATE public.factures
     SET montant_paye = montant_paye + a.montant, updated_at = now()
   WHERE facture_id = _facture_id;

  UPDATE public.avoirs
     SET statut = 'impute',
         facture_imputee_id = _facture_id,
         paiement_id = v_pid,
         date_reglement = CURRENT_DATE,
         updated_at = now()
   WHERE avoir_id = _avoir_id
  RETURNING * INTO a;

  RETURN a;
END $$;

GRANT EXECUTE ON FUNCTION public.imputer_avoir_sur_facture(uuid, uuid) TO authenticated;