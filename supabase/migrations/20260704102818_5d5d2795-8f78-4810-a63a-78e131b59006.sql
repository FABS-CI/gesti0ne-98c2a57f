-- 1) Audit table for payment cancellations
CREATE TABLE IF NOT EXISTS public.paiement_annulations_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paiement_id uuid NOT NULL REFERENCES public.paiements(paiement_id) ON DELETE CASCADE,
  facture_id uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  annule_par uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  annule_le timestamptz NOT NULL DEFAULT now(),
  raison text NOT NULL,
  notes text,
  montant_annule numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.paiement_annulations_audit TO authenticated;
GRANT ALL ON public.paiement_annulations_audit TO service_role;

ALTER TABLE public.paiement_annulations_audit ENABLE ROW LEVEL SECURITY;

-- Only admins can read the audit log
CREATE POLICY "admins read paiement_annulations_audit"
  ON public.paiement_annulations_audit FOR SELECT
  TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::app_role[]));

-- No direct INSERT policy: writes go through SECURITY DEFINER RPC only.
-- (RLS blocks direct inserts from clients even with GRANT.)

CREATE INDEX IF NOT EXISTS idx_pay_annul_audit_paiement ON public.paiement_annulations_audit(paiement_id);
CREATE INDEX IF NOT EXISTS idx_pay_annul_audit_date ON public.paiement_annulations_audit(annule_le DESC);

-- 2) Overload annuler_paiement to accept raison + notes and write audit row
CREATE OR REPLACE FUNCTION public.annuler_paiement(
  _paiement_id uuid,
  _raison text,
  _notes text DEFAULT NULL
)
RETURNS paiements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_p public.paiements;
  v_fac record;
  v_total_paye numeric;
  v_nouveau_statut text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée pour annuler un paiement';
  END IF;
  IF _raison IS NULL OR btrim(_raison) = '' THEN
    RAISE EXCEPTION 'Raison d''annulation obligatoire';
  END IF;

  SELECT * INTO v_p FROM public.paiements WHERE paiement_id = _paiement_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;
  IF v_p.statut = 'annule' THEN RAISE EXCEPTION 'Paiement déjà annulé'; END IF;

  UPDATE public.paiements
     SET statut = 'annule',
         updated_at = now(),
         notes = COALESCE(notes,'') || E'\n[Annulé le ' || to_char(now(),'YYYY-MM-DD HH24:MI') || '] ' || _raison
   WHERE paiement_id = _paiement_id
   RETURNING * INTO v_p;

  IF v_p.facture_id IS NOT NULL THEN
    SELECT * INTO v_fac FROM public.factures WHERE facture_id = v_p.facture_id FOR UPDATE;
    IF FOUND THEN
      v_total_paye := GREATEST(0, COALESCE(v_fac.montant_paye, 0) - COALESCE(v_p.montant, 0));
      IF v_total_paye >= COALESCE(v_fac.montant_total, 0) AND COALESCE(v_fac.montant_total,0) > 0 THEN
        v_nouveau_statut := 'payee';
      ELSIF v_total_paye > 0 THEN
        v_nouveau_statut := 'partielle';
      ELSE
        v_nouveau_statut := 'impayee';
      END IF;
      UPDATE public.factures
         SET montant_paye = v_total_paye,
             statut = v_nouveau_statut,
             updated_at = now()
       WHERE facture_id = v_fac.facture_id;
    END IF;
  END IF;

  INSERT INTO public.paiement_annulations_audit
    (paiement_id, facture_id, annule_par, raison, notes, montant_annule)
  VALUES
    (v_p.paiement_id, v_p.facture_id, auth.uid(), _raison, _notes, COALESCE(v_p.montant, 0));

  RETURN v_p;
END $function$;

GRANT EXECUTE ON FUNCTION public.annuler_paiement(uuid, text, text) TO authenticated;