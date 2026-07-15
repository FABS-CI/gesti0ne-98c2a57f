
-- Restreindre la lecture de tables sensibles aux membres du personnel (is_staff)
-- au lieu de tout utilisateur authentifié.

-- ERRORS du scan : données PII / fiscales
DROP POLICY IF EXISTS "auth read historique_envois" ON public.historique_envois;
CREATE POLICY "staff read historique_envois" ON public.historique_envois
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()) OR envoye_par = auth.uid());

DROP POLICY IF EXISTS "auth read fne_logs" ON public.fne_logs;
CREATE POLICY "staff read fne_logs" ON public.fne_logs
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

-- WARNINGS : aligner sur le modèle staff-only des tables parentes
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'bons_livraison','transferts','transfert_lignes','inventaires','inventaire_lignes',
    'stocks_depots','depots','expeditions','specimens','specimen_lignes','bons_retour',
    'achat_lignes','retour_lignes','incident_lignes','ordres_colisage','fonctions','categories_produits'
  ]) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'auth read '||t, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_staff(auth.uid()))',
      'staff read '||t, t
    );
  END LOOP;
END $$;
