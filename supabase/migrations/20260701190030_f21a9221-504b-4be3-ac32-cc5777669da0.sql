
-- ============================================================
-- 1) HR / Payroll: tighten RLS beyond broad is_staff()
-- ============================================================

-- Helpers pour lisibilité
-- Rôles RH généraux : super_admin, directeur_general, secretariat
-- Rôles Paie/Compta : super_admin, directeur_general, comptable
-- Rôle Évaluations   : super_admin, directeur_general

-- BULLETINS DE PAIE (payroll — comptable uniquement)
DROP POLICY IF EXISTS "staff read bulletins_paie" ON public.bulletins_paie;
DROP POLICY IF EXISTS "staff write bulletins_paie" ON public.bulletins_paie;
CREATE POLICY "paie read bulletins_paie" ON public.bulletins_paie
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::public.app_role[]));
CREATE POLICY "paie write bulletins_paie" ON public.bulletins_paie
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::public.app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::public.app_role[]));

-- EMPLOYES (RH)
DROP POLICY IF EXISTS "staff read employes" ON public.employes;
DROP POLICY IF EXISTS "staff write employes" ON public.employes;
CREATE POLICY "rh read employes" ON public.employes
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat','comptable']::public.app_role[]));
CREATE POLICY "rh write employes" ON public.employes
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[]));

-- CONTRATS (RH)
DROP POLICY IF EXISTS "staff read contrats" ON public.contrats;
DROP POLICY IF EXISTS "staff write contrats" ON public.contrats;
CREATE POLICY "rh read contrats" ON public.contrats
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat','comptable']::public.app_role[]));
CREATE POLICY "rh write contrats" ON public.contrats
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[]));

-- ABSENCES / CONGES / MISSIONS (RH)
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['absences','conges','missions'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "staff read %1$s" ON public.%1$I', t);
    EXECUTE format('DROP POLICY IF EXISTS "staff write %1$s" ON public.%1$I', t);
    EXECUTE format($p$CREATE POLICY "rh read %1$s" ON public.%1$I FOR SELECT TO authenticated USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat','comptable']::public.app_role[]))$p$, t);
    EXECUTE format($p$CREATE POLICY "rh write %1$s" ON public.%1$I FOR ALL TO authenticated USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[])) WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[]))$p$, t);
  END LOOP;
END $$;

-- EVALUATIONS (Direction Générale uniquement)
DROP POLICY IF EXISTS "staff read evaluations" ON public.evaluations;
DROP POLICY IF EXISTS "staff write evaluations" ON public.evaluations;
CREATE POLICY "dg read evaluations" ON public.evaluations
  FOR SELECT TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[]));
CREATE POLICY "dg write evaluations" ON public.evaluations
  FOR ALL TO authenticated
  USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[]))
  WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[]));

-- DEPARTEMENTS / FONCTIONS (structure RH)
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['departements','fonctions'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "staff read %1$s" ON public.%1$I', t);
    EXECUTE format('DROP POLICY IF EXISTS "staff write %1$s" ON public.%1$I', t);
    EXECUTE format('DROP POLICY IF EXISTS "auth read %1$s" ON public.%1$I', t);
    -- Lecture par tous les staff (utilisé pour affichage de listes déroulantes)
    EXECUTE format($p$CREATE POLICY "staff read %1$s" ON public.%1$I FOR SELECT TO authenticated USING (public.is_staff(auth.uid()))$p$, t);
    -- Écriture réservée à la direction/RH
    EXECUTE format($p$CREATE POLICY "rh write %1$s" ON public.%1$I FOR ALL TO authenticated USING (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[])) WITH CHECK (public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','secretariat']::public.app_role[]))$p$, t);
  END LOOP;
END $$;

-- ============================================================
-- 2) FNE settings: hide DGI API key from browser
-- ============================================================

DROP POLICY IF EXISTS "Super admin DG manage fne settings" ON public.fne_settings;
DROP POLICY IF EXISTS "Admin manage fne_settings" ON public.fne_settings;
DROP POLICY IF EXISTS "fne_settings admin" ON public.fne_settings;
DROP POLICY IF EXISTS "fne_settings read" ON public.fne_settings;
DROP POLICY IF EXISTS "fne_settings write" ON public.fne_settings;

-- Lecture : Super Admin & DG uniquement, ET jamais la clé DGI (elle vit côté serveur / service_role)
CREATE POLICY "fne_settings read (no secret)" ON public.fne_settings
  FOR SELECT TO authenticated
  USING (
    cle <> 'dgi_api_key'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[])
  );

-- Écriture (insert/update/delete) : Super Admin & DG, sur toutes les clés SAUF la clé DGI
CREATE POLICY "fne_settings write (no secret)" ON public.fne_settings
  FOR ALL TO authenticated
  USING (
    cle <> 'dgi_api_key'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[])
  )
  WITH CHECK (
    cle <> 'dgi_api_key'
    AND public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general']::public.app_role[])
  );
