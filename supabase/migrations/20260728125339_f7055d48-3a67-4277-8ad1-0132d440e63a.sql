-- ============================================================
-- Lot RLS-2 : encadrement des écritures Ventes / Stock / Logistique
-- Lecture inchangée. Helper unique de contrôle d'écriture.
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_write_module(VARIADIC _modules text[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL
     AND (
       public.is_admin(auth.uid())
       OR EXISTS (
         SELECT 1
         FROM unnest(_modules) m
         CROSS JOIN unnest(ARRAY['creer','modifier','supprimer','valider']) a
         WHERE public.has_permission(auth.uid(), m || '.' || a)
       )
     );
$$;

GRANT EXECUTE ON FUNCTION public.can_write_module(text[]) TO authenticated, service_role;

-- ---------- Catalogue ----------
DROP POLICY IF EXISTS "Authenticated write produits" ON public.produits;
CREATE POLICY produits_write ON public.produits
  FOR ALL TO authenticated
  USING (can_write_module('produits','stock'))
  WITH CHECK (can_write_module('produits','stock'));

DROP POLICY IF EXISTS auth_categ_prod ON public.categories_produits;
CREATE POLICY categories_produits_read ON public.categories_produits
  FOR SELECT TO authenticated USING (true);
CREATE POLICY categories_produits_write ON public.categories_produits
  FOR ALL TO authenticated
  USING (can_write_module('produits','parametres'))
  WITH CHECK (can_write_module('produits','parametres'));

-- ---------- Ventes ----------
DROP POLICY IF EXISTS auth_write_proformas ON public.proformas;
CREATE POLICY proformas_write ON public.proformas
  FOR ALL TO authenticated
  USING (can_write_module('proformas'))
  WITH CHECK (can_write_module('proformas'));

DROP POLICY IF EXISTS auth_write_proforma_lignes ON public.proforma_lignes;
CREATE POLICY proforma_lignes_write ON public.proforma_lignes
  FOR ALL TO authenticated
  USING (can_write_module('proformas'))
  WITH CHECK (can_write_module('proformas'));

DROP POLICY IF EXISTS auth_write_specimens ON public.specimens;
CREATE POLICY specimens_write ON public.specimens
  FOR ALL TO authenticated
  USING (can_write_module('specimens'))
  WITH CHECK (can_write_module('specimens'));

DROP POLICY IF EXISTS specimen_lignes_write_auth ON public.specimen_lignes;
CREATE POLICY specimen_lignes_write ON public.specimen_lignes
  FOR ALL TO authenticated
  USING (can_write_module('specimens'))
  WITH CHECK (can_write_module('specimens'));

DROP POLICY IF EXISTS auth_write_retour_lignes ON public.retour_lignes;
CREATE POLICY retour_lignes_write ON public.retour_lignes
  FOR ALL TO authenticated
  USING (can_write_module('retours'))
  WITH CHECK (can_write_module('retours'));

-- ---------- Logistique ----------
DROP POLICY IF EXISTS auth_write_livraisons ON public.livraisons;
CREATE POLICY livraisons_write ON public.livraisons
  FOR ALL TO authenticated
  USING (can_write_module('livraisons'))
  WITH CHECK (can_write_module('livraisons'));

DROP POLICY IF EXISTS livraisons_commande_all_authenticated ON public.livraisons_commande;
DROP POLICY IF EXISTS livraisons_commande_service_role ON public.livraisons_commande;
CREATE POLICY livraisons_commande_read ON public.livraisons_commande
  FOR SELECT TO authenticated USING (true);
CREATE POLICY livraisons_commande_write ON public.livraisons_commande
  FOR ALL TO authenticated
  USING (can_write_module('livraisons','livraison_suivi'))
  WITH CHECK (can_write_module('livraisons','livraison_suivi'));

DROP POLICY IF EXISTS livsuivi_commandes_all_authenticated ON public.livsuivi_commandes;
DROP POLICY IF EXISTS livsuivi_commandes_service_role ON public.livsuivi_commandes;
CREATE POLICY livsuivi_commandes_read ON public.livsuivi_commandes
  FOR SELECT TO authenticated USING (true);
CREATE POLICY livsuivi_commandes_write ON public.livsuivi_commandes
  FOR ALL TO authenticated
  USING (can_write_module('livraison_suivi','livraisons'))
  WITH CHECK (can_write_module('livraison_suivi','livraisons'));

DROP POLICY IF EXISTS livsuivi_historique_all_authenticated ON public.livsuivi_historique;
DROP POLICY IF EXISTS livsuivi_historique_service_role ON public.livsuivi_historique;
CREATE POLICY livsuivi_historique_read ON public.livsuivi_historique
  FOR SELECT TO authenticated USING (true);
CREATE POLICY livsuivi_historique_insert ON public.livsuivi_historique
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS expeditions_all_authenticated ON public.expeditions;
DROP POLICY IF EXISTS expeditions_service_role ON public.expeditions;
CREATE POLICY expeditions_read ON public.expeditions
  FOR SELECT TO authenticated USING (true);
CREATE POLICY expeditions_write ON public.expeditions
  FOR ALL TO authenticated
  USING (can_write_module('expeditions','livraisons'))
  WITH CHECK (can_write_module('expeditions','livraisons'));

DROP POLICY IF EXISTS auth_write_preparateurs_colisage ON public.preparateurs_colisage;
CREATE POLICY preparateurs_colisage_write ON public.preparateurs_colisage
  FOR ALL TO authenticated
  USING (can_write_module('colisage'))
  WITH CHECK (can_write_module('colisage'));

DROP POLICY IF EXISTS auth_write_missions ON public.missions;
CREATE POLICY missions_write ON public.missions
  FOR ALL TO authenticated
  USING (can_write_module('missions'))
  WITH CHECK (can_write_module('missions'));

DROP POLICY IF EXISTS auth_write_couts_logistiques ON public.couts_logistiques;
CREATE POLICY couts_logistiques_write ON public.couts_logistiques
  FOR ALL TO authenticated
  USING (can_write_module('couts_logistiques'))
  WITH CHECK (can_write_module('couts_logistiques'));

-- ---------- Stock ----------
DROP POLICY IF EXISTS auth_write_approvisionnements ON public.approvisionnements;
CREATE POLICY approvisionnements_write ON public.approvisionnements
  FOR ALL TO authenticated
  USING (can_write_module('approvisionnements','stock'))
  WITH CHECK (can_write_module('approvisionnements','stock'));

DROP POLICY IF EXISTS auth_write_approvisionnement_lignes ON public.approvisionnement_lignes;
CREATE POLICY approvisionnement_lignes_write ON public.approvisionnement_lignes
  FOR ALL TO authenticated
  USING (can_write_module('approvisionnements','stock'))
  WITH CHECK (can_write_module('approvisionnements','stock'));

DROP POLICY IF EXISTS auth_write_inventaire_lignes ON public.inventaire_lignes;
CREATE POLICY inventaire_lignes_write ON public.inventaire_lignes
  FOR ALL TO authenticated
  USING (can_write_module('inventaires','stock'))
  WITH CHECK (can_write_module('inventaires','stock'));

DROP POLICY IF EXISTS auth_write_transfert_lignes ON public.transfert_lignes;
CREATE POLICY transfert_lignes_write ON public.transfert_lignes
  FOR ALL TO authenticated
  USING (can_write_module('transferts','stock'))
  WITH CHECK (can_write_module('transferts','stock'));

DROP POLICY IF EXISTS auth_write_incidents_stock ON public.incidents;
CREATE POLICY incidents_write ON public.incidents
  FOR ALL TO authenticated
  USING (can_write_module('incidents','stock'))
  WITH CHECK (can_write_module('incidents','stock'));

DROP POLICY IF EXISTS incident_lignes_write_auth ON public.incident_lignes;
CREATE POLICY incident_lignes_write ON public.incident_lignes
  FOR ALL TO authenticated
  USING (can_write_module('incidents','stock'))
  WITH CHECK (can_write_module('incidents','stock'));

DROP POLICY IF EXISTS auth_write_incident_alerts ON public.incident_alerts;
CREATE POLICY incident_alerts_write ON public.incident_alerts
  FOR ALL TO authenticated
  USING (can_write_module('incidents','stock'))
  WITH CHECK (can_write_module('incidents','stock'));

-- ---------- Référentiels logistiques ----------
DROP POLICY IF EXISTS auth_write_livreurs ON public.livreurs;
CREATE POLICY livreurs_write ON public.livreurs
  FOR ALL TO authenticated
  USING (can_write_module('livraisons','parametres'))
  WITH CHECK (can_write_module('livraisons','parametres'));

DROP POLICY IF EXISTS auth_write_vehicules ON public.vehicules;
CREATE POLICY vehicules_write ON public.vehicules
  FOR ALL TO authenticated
  USING (can_write_module('livraisons','parametres'))
  WITH CHECK (can_write_module('livraisons','parametres'));

DROP POLICY IF EXISTS auth_write_preparateurs ON public.preparateurs;
CREATE POLICY preparateurs_write ON public.preparateurs
  FOR ALL TO authenticated
  USING (can_write_module('colisage','parametres'))
  WITH CHECK (can_write_module('colisage','parametres'));

DROP POLICY IF EXISTS transporteurs_all_authenticated ON public.transporteurs;
DROP POLICY IF EXISTS transporteurs_service_role ON public.transporteurs;
CREATE POLICY transporteurs_read ON public.transporteurs
  FOR SELECT TO authenticated USING (true);
CREATE POLICY transporteurs_write ON public.transporteurs
  FOR ALL TO authenticated
  USING (can_write_module('expeditions','livraisons','parametres'))
  WITH CHECK (can_write_module('expeditions','livraisons','parametres'));

DROP POLICY IF EXISTS gares_all_authenticated ON public.gares;
DROP POLICY IF EXISTS gares_service_role ON public.gares;
CREATE POLICY gares_read ON public.gares
  FOR SELECT TO authenticated USING (true);
CREATE POLICY gares_write ON public.gares
  FOR ALL TO authenticated
  USING (can_write_module('expeditions','livraisons','parametres'))
  WITH CHECK (can_write_module('expeditions','livraisons','parametres'));

-- ---------- CRM / Documents ----------
DROP POLICY IF EXISTS auth_write_crm_interactions ON public.crm_interactions;
CREATE POLICY crm_interactions_write ON public.crm_interactions
  FOR ALL TO authenticated
  USING (can_write_module('crm','clients'))
  WITH CHECK (can_write_module('crm','clients'));

DROP POLICY IF EXISTS auth_documents ON public.documents;
CREATE POLICY documents_read ON public.documents
  FOR SELECT TO authenticated USING (true);
CREATE POLICY documents_write ON public.documents
  FOR ALL TO authenticated
  USING (can_write_module('documents'))
  WITH CHECK (can_write_module('documents'));
