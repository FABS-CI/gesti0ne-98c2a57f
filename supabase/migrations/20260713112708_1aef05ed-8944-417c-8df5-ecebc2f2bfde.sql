
-- ============================================================
-- BLOC 1 — Alignement écritures sur has_permission_v2
-- ============================================================

-- FACTURES
DROP POLICY IF EXISTS "commercial write factures" ON public.factures;
CREATE POLICY "rbac insert factures" ON public.factures FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'factures.creer'));
CREATE POLICY "rbac update factures" ON public.factures FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'factures.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'factures.modifier'));
CREATE POLICY "rbac delete factures" ON public.factures FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'factures.supprimer'));

-- PAIEMENTS
DROP POLICY IF EXISTS "commercial write paiements" ON public.paiements;
CREATE POLICY "rbac insert paiements" ON public.paiements FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'paiements.creer'));
CREATE POLICY "rbac update paiements" ON public.paiements FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'paiements.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'paiements.modifier'));
CREATE POLICY "rbac delete paiements" ON public.paiements FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'paiements.supprimer'));

-- AVOIRS
DROP POLICY IF EXISTS "finance write avoirs" ON public.avoirs;
CREATE POLICY "rbac insert avoirs" ON public.avoirs FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'avoirs.creer'));
CREATE POLICY "rbac update avoirs" ON public.avoirs FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'avoirs.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'avoirs.modifier'));
CREATE POLICY "rbac delete avoirs" ON public.avoirs FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'avoirs.supprimer'));

-- PROFORMAS
DROP POLICY IF EXISTS "commercial write proformas" ON public.proformas;
CREATE POLICY "rbac insert proformas" ON public.proformas FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'proformas.creer'));
CREATE POLICY "rbac update proformas" ON public.proformas FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'proformas.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'proformas.modifier'));
CREATE POLICY "rbac delete proformas" ON public.proformas FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'proformas.supprimer'));

-- RETOURS
DROP POLICY IF EXISTS "commercial write retours" ON public.retours;
CREATE POLICY "rbac insert retours" ON public.retours FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'retours.creer'));
CREATE POLICY "rbac update retours" ON public.retours FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'retours.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'retours.modifier'));
CREATE POLICY "rbac delete retours" ON public.retours FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'retours.supprimer'));

-- BONS_LIVRAISON (utilise les permissions commandes.* via convertir_en_bl)
DROP POLICY IF EXISTS "operational write bons_livraison" ON public.bons_livraison;
CREATE POLICY "rbac insert bons_livraison" ON public.bons_livraison FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'commandes.convertir_en_bl'));
CREATE POLICY "rbac update bons_livraison" ON public.bons_livraison FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'commandes.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'commandes.modifier'));
CREATE POLICY "rbac delete bons_livraison" ON public.bons_livraison FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'commandes.supprimer'));

-- COMMANDE_LIGNES (aligné sur commandes.modifier)
DROP POLICY IF EXISTS "staff write commande_lignes" ON public.commande_lignes;
CREATE POLICY "rbac insert commande_lignes" ON public.commande_lignes FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'commandes.modifier'));
CREATE POLICY "rbac update commande_lignes" ON public.commande_lignes FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'commandes.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'commandes.modifier'));
CREATE POLICY "rbac delete commande_lignes" ON public.commande_lignes FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'commandes.modifier'));

-- PROFORMA_LIGNES
DROP POLICY IF EXISTS "staff write proforma_lignes" ON public.proforma_lignes;
CREATE POLICY "rbac insert proforma_lignes" ON public.proforma_lignes FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'proformas.modifier'));
CREATE POLICY "rbac update proforma_lignes" ON public.proforma_lignes FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'proformas.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'proformas.modifier'));
CREATE POLICY "rbac delete proforma_lignes" ON public.proforma_lignes FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'proformas.modifier'));

-- RETOUR_LIGNES
DROP POLICY IF EXISTS "staff write retour_lignes" ON public.retour_lignes;
CREATE POLICY "rbac insert retour_lignes" ON public.retour_lignes FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'retours.modifier'));
CREATE POLICY "rbac update retour_lignes" ON public.retour_lignes FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'retours.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'retours.modifier'));
CREATE POLICY "rbac delete retour_lignes" ON public.retour_lignes FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'retours.modifier'));

-- ACHAT_LIGNES
DROP POLICY IF EXISTS "staff write achat_lignes" ON public.achat_lignes;
CREATE POLICY "rbac insert achat_lignes" ON public.achat_lignes FOR INSERT TO authenticated
  WITH CHECK (public.has_permission_v2(auth.uid(), 'achats.modifier'));
CREATE POLICY "rbac update achat_lignes" ON public.achat_lignes FOR UPDATE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'achats.modifier'))
  WITH CHECK (public.has_permission_v2(auth.uid(), 'achats.modifier'));
CREATE POLICY "rbac delete achat_lignes" ON public.achat_lignes FOR DELETE TO authenticated
  USING (public.has_permission_v2(auth.uid(), 'achats.modifier'));
