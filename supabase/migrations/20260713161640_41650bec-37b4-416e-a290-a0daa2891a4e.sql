
-- 1) colisage_responsables: scope UPDATE to super_admin OR same depot as the caller's own assignment
DROP POLICY IF EXISTS "colisage_resp update" ON public.colisage_responsables;
CREATE POLICY "colisage_resp update"
  ON public.colisage_responsables
  FOR UPDATE
  USING (
    has_role(auth.uid(), 'super_admin'::app_role)
    OR (
      (has_role(auth.uid(), 'gestionnaire_stock'::app_role)
        OR has_role(auth.uid(), 'responsable_magasinier'::app_role))
      AND EXISTS (
        SELECT 1 FROM public.colisage_responsables cr
        WHERE cr.employe_id = auth.uid()
          AND cr.depot_id = colisage_responsables.depot_id
          AND COALESCE(cr.actif, true)
      )
    )
  )
  WITH CHECK (
    has_role(auth.uid(), 'super_admin'::app_role)
    OR (
      (has_role(auth.uid(), 'gestionnaire_stock'::app_role)
        OR has_role(auth.uid(), 'responsable_magasinier'::app_role))
      AND EXISTS (
        SELECT 1 FROM public.colisage_responsables cr
        WHERE cr.employe_id = auth.uid()
          AND cr.depot_id = colisage_responsables.depot_id
          AND COALESCE(cr.actif, true)
      )
    )
  );

-- 2) fne_settings: replace fragile NOT LIKE 'dgi_api_key%' filter with a dedicated is_secret flag
ALTER TABLE public.fne_settings
  ADD COLUMN IF NOT EXISTS is_secret boolean NOT NULL DEFAULT false;

UPDATE public.fne_settings
   SET is_secret = true
 WHERE cle ILIKE 'dgi_api_key%'
    OR btrim(lower(cle)) LIKE 'dgi_api_key%';

DROP POLICY IF EXISTS "fne_settings read (no dgi keys)" ON public.fne_settings;
DROP POLICY IF EXISTS "fne_settings write (no dgi keys)" ON public.fne_settings;

CREATE POLICY "fne_settings read non-secret"
  ON public.fne_settings
  FOR SELECT
  USING (
    is_secret = false
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role])
  );

CREATE POLICY "fne_settings write non-secret"
  ON public.fne_settings
  FOR ALL
  USING (
    is_secret = false
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role])
  )
  WITH CHECK (
    is_secret = false
    AND has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role])
  );

-- 3) numerotation_compteurs: restrict SELECT to staff (was USING (true))
DROP POLICY IF EXISTS "read compteurs" ON public.numerotation_compteurs;
CREATE POLICY "read compteurs (staff only)"
  ON public.numerotation_compteurs
  FOR SELECT
  USING (public.is_staff(auth.uid()));

-- 4) Fix mutable search_path on _raise_bad_transition
ALTER FUNCTION public._raise_bad_transition(text, text, text) SET search_path = public;
