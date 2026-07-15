
-- 1. Étendre la table notifications
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS role_cible public.app_role,
  ADD COLUMN IF NOT EXISTS module text,
  ADD COLUMN IF NOT EXISTS document_type text,
  ADD COLUMN IF NOT EXISTS document_id uuid,
  ADD COLUMN IF NOT EXISTS document_reference text,
  ADD COLUMN IF NOT EXISTS lien text,
  ADD COLUMN IF NOT EXISTS priorite text NOT NULL DEFAULT 'normale';

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, lu, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_role ON public.notifications(role_cible, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_module ON public.notifications(module);

-- 2. RLS mise à jour
DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their notifications" ON public.notifications;
DROP POLICY IF EXISTS "Staff manage notifications" ON public.notifications;

CREATE POLICY "notifs_select_own_or_role" ON public.notifications
  FOR SELECT TO authenticated USING (
    public.has_role(auth.uid(), 'super_admin')
    OR user_id = auth.uid()
    OR (user_id IS NULL AND role_cible IS NULL)
    OR (user_id IS NULL AND role_cible IS NOT NULL AND public.has_role(auth.uid(), role_cible))
  );

CREATE POLICY "notifs_update_own" ON public.notifications
  FOR UPDATE TO authenticated USING (
    public.has_role(auth.uid(), 'super_admin')
    OR user_id = auth.uid()
    OR (user_id IS NULL AND role_cible IS NOT NULL AND public.has_role(auth.uid(), role_cible))
    OR (user_id IS NULL AND role_cible IS NULL)
  );

CREATE POLICY "notifs_delete_own" ON public.notifications
  FOR DELETE TO authenticated USING (
    public.has_role(auth.uid(), 'super_admin') OR user_id = auth.uid()
  );

CREATE POLICY "notifs_insert_staff" ON public.notifications
  FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

-- Realtime
DO $$ BEGIN
  BEGIN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications';
  EXCEPTION WHEN duplicate_object THEN NULL; WHEN others THEN NULL; END;
END $$;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- 3. Table préférences
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  son_actif boolean NOT NULL DEFAULT true,
  volume int NOT NULL DEFAULT 70 CHECK (volume BETWEEN 0 AND 100),
  types_desactives text[] NOT NULL DEFAULT '{}',
  modules_desactives text[] NOT NULL DEFAULT '{}',
  notifs_navigateur boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_preferences TO authenticated;
GRANT ALL ON public.notification_preferences TO service_role;

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "prefs_own" ON public.notification_preferences;
CREATE POLICY "prefs_own" ON public.notification_preferences
  FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP TRIGGER IF EXISTS trg_notif_prefs_updated ON public.notification_preferences;
CREATE TRIGGER trg_notif_prefs_updated BEFORE UPDATE ON public.notification_preferences
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 4. Fonction générique de création
CREATE OR REPLACE FUNCTION public.creer_notification(
  _titre text, _message text, _type text DEFAULT 'info',
  _module text DEFAULT NULL, _document_type text DEFAULT NULL,
  _document_id uuid DEFAULT NULL, _document_reference text DEFAULT NULL,
  _lien text DEFAULT NULL, _role_cible public.app_role DEFAULT NULL,
  _user_id uuid DEFAULT NULL, _priorite text DEFAULT 'normale'
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO public.notifications(
    titre, message, type_notification, date_notification, lu,
    user_id, role_cible, module, document_type, document_id, document_reference, lien, priorite
  ) VALUES(
    _titre, _message, COALESCE(_type,'info'), current_date, false,
    _user_id, _role_cible, _module, _document_type, _document_id, _document_reference, _lien, COALESCE(_priorite,'normale')
  ) RETURNING notification_id INTO v_id;
  RETURN v_id;
END $$;

-- 5. Triggers métier
-- Commandes
CREATE OR REPLACE FUNCTION public.trg_notif_commandes() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ref text; v_client text;
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.creer_notification(
      'Nouvelle commande — '||NEW.reference,
      COALESCE(NEW.client_nom,'')||' • '||to_char(COALESCE(NEW.montant_total,0),'FM999G999G990')||' FCFA',
      'info','commandes','commandes',NEW.commande_id,NEW.reference,
      '/commandes/'||NEW.commande_id,'directeur_commercial',NULL,'normale');
    PERFORM public.creer_notification(
      'Nouvelle commande — '||NEW.reference, COALESCE(NEW.client_nom,''),
      'info','commandes','commandes',NEW.commande_id,NEW.reference,
      '/commandes/'||NEW.commande_id,'service_logistique',NULL,'normale');
  ELSIF TG_OP='UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    IF NEW.statut='validee' THEN
      PERFORM public.creer_notification('Commande validée — '||NEW.reference, COALESCE(NEW.client_nom,''),
        'succes','commandes','commandes',NEW.commande_id,NEW.reference,'/commandes/'||NEW.commande_id,
        'service_logistique',NULL,'normale');
      PERFORM public.creer_notification('Commande validée — '||NEW.reference, COALESCE(NEW.client_nom,''),
        'succes','commandes','commandes',NEW.commande_id,NEW.reference,'/commandes/'||NEW.commande_id,
        'responsable_magasinier',NULL,'normale');
    ELSIF NEW.statut='annulee' THEN
      PERFORM public.creer_notification('Commande annulée — '||NEW.reference, COALESCE(NEW.client_nom,''),
        'alerte','commandes','commandes',NEW.commande_id,NEW.reference,'/commandes/'||NEW.commande_id,
        'directeur_commercial',NULL,'haute');
    END IF;
  ELSIF TG_OP='DELETE' THEN
    PERFORM public.creer_notification('Commande supprimée — '||OLD.reference,
      COALESCE(OLD.client_nom,''),'erreur','commandes','commandes',OLD.commande_id,OLD.reference,
      NULL,'super_admin',NULL,'critique');
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;
DROP TRIGGER IF EXISTS trg_notif_commandes ON public.commandes;
CREATE TRIGGER trg_notif_commandes AFTER INSERT OR UPDATE OR DELETE ON public.commandes
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_commandes();

-- Factures
CREATE OR REPLACE FUNCTION public.trg_notif_factures() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.creer_notification('Nouvelle facture — '||NEW.reference,
      COALESCE(NEW.client_nom,'')||' • '||to_char(COALESCE(NEW.montant_total,0),'FM999G999G990')||' FCFA',
      'info','factures','factures',NEW.facture_id,NEW.reference,'/factures/'||NEW.facture_id,
      'comptable',NULL,'normale');
  ELSIF TG_OP='UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    IF NEW.statut='payee' THEN
      PERFORM public.creer_notification('Facture soldée — '||NEW.reference, COALESCE(NEW.client_nom,''),
        'succes','factures','factures',NEW.facture_id,NEW.reference,'/factures/'||NEW.facture_id,
        'comptable',NULL,'normale');
    ELSIF NEW.statut='annulee' THEN
      PERFORM public.creer_notification('Facture annulée — '||NEW.reference, COALESCE(NEW.client_nom,''),
        'alerte','factures','factures',NEW.facture_id,NEW.reference,'/factures/'||NEW.facture_id,
        'comptable',NULL,'haute');
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;
DROP TRIGGER IF EXISTS trg_notif_factures ON public.factures;
CREATE TRIGGER trg_notif_factures AFTER INSERT OR UPDATE ON public.factures
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_factures();

-- Paiements
CREATE OR REPLACE FUNCTION public.trg_notif_paiements() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.creer_notification('Paiement enregistré',
    'Montant: '||to_char(COALESCE(NEW.montant,0),'FM999G999G990')||' FCFA'||
    CASE WHEN NEW.facture_id IS NOT NULL THEN ' • Facture '||NEW.facture_id::text ELSE '' END,
    'succes','paiements','paiements',NEW.paiement_id, NEW.reference,
    '/paiements/'||NEW.paiement_id,'comptable',NULL,'normale');
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_paiements ON public.paiements;
CREATE TRIGGER trg_notif_paiements AFTER INSERT ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_paiements();

-- Bons de livraison : colisage terminé
CREATE OR REPLACE FUNCTION public.trg_notif_bl() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP='UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut AND NEW.statut='colisage_termine' THEN
    PERFORM public.creer_notification('Colisage terminé — '||NEW.reference,
      'Commande prête à être livrée','succes','colisage','bons_livraison',NEW.bl_id,NEW.reference,
      '/bons-livraison','service_logistique',NULL,'normale');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_bl ON public.bons_livraison;
CREATE TRIGGER trg_notif_bl AFTER UPDATE ON public.bons_livraison
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_bl();

-- Tournées
CREATE OR REPLACE FUNCTION public.trg_notif_tournees() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.creer_notification('Nouvelle tournée — '||COALESCE(NEW.reference,''),
      COALESCE('Date: '||NEW.date_tournee::text,''),'info','tournees','tournees',NEW.id,NEW.reference,
      '/tournees','service_logistique',NULL,'normale');
  ELSIF TG_OP='UPDATE' AND OLD.livreur_id IS DISTINCT FROM NEW.livreur_id AND NEW.livreur_id IS NOT NULL THEN
    PERFORM public.creer_notification('Livreur affecté — '||COALESCE(NEW.reference,''),
      'Un livreur a été affecté à la tournée','info','tournees','tournees',NEW.id,NEW.reference,
      '/tournees','service_logistique',NULL,'normale');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_tournees ON public.tournees;
CREATE TRIGGER trg_notif_tournees AFTER INSERT OR UPDATE ON public.tournees
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_tournees();

-- Livraisons commande : départ, livraison, incident
CREATE OR REPLACE FUNCTION public.trg_notif_livraisons() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_ref text;
BEGIN
  IF TG_OP='UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    SELECT reference INTO v_ref FROM public.commandes WHERE commande_id = NEW.commande_id;
    IF NEW.statut::text = 'en_cours_livraison' OR NEW.statut::text='expediee' THEN
      PERFORM public.creer_notification('Départ en livraison — '||COALESCE(v_ref,''),
        'La livraison est en cours','info','livraisons','livraisons_commande',NEW.id, v_ref,
        '/suivi-livraison','service_logistique',NULL,'normale');
    ELSIF NEW.statut::text IN ('livree','livraison_confirmee','retiree_client') THEN
      PERFORM public.creer_notification('Livraison effectuée — '||COALESCE(v_ref,''),
        'Livraison terminée','succes','livraisons','livraisons_commande',NEW.id, v_ref,
        '/suivi-livraison','directeur_commercial',NULL,'normale');
      PERFORM public.creer_notification('Livraison effectuée — '||COALESCE(v_ref,''),
        'Livraison terminée','succes','livraisons','livraisons_commande',NEW.id, v_ref,
        '/suivi-livraison','service_logistique',NULL,'normale');
    ELSIF NEW.statut::text='anomalie' THEN
      PERFORM public.creer_notification('Incident livraison — '||COALESCE(v_ref,''),
        COALESCE(NEW.anomalie_motif,'Incident signalé'),'erreur','livraisons','livraisons_commande',
        NEW.id, v_ref,'/suivi-livraison','service_logistique',NULL,'haute');
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_livraisons ON public.livraisons_commande;
CREATE TRIGGER trg_notif_livraisons AFTER UPDATE ON public.livraisons_commande
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_livraisons();

-- Stock : alerte faible / rupture
CREATE OR REPLACE FUNCTION public.trg_notif_stock() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_titre text; v_seuil int; v_stock int;
BEGIN
  IF NEW.stock IS NULL THEN RETURN NEW; END IF;
  IF OLD.stock IS NOT DISTINCT FROM NEW.stock THEN RETURN NEW; END IF;
  v_stock := NEW.stock; v_seuil := COALESCE(NEW.seuil_alerte,0);
  IF v_stock <= 0 AND COALESCE(OLD.stock,0) > 0 THEN
    PERFORM public.creer_notification('Rupture de stock — '||NEW.titre,
      'Stock épuisé','erreur','stock','produits',NEW.produit_id,NEW.reference,
      '/stock','gestionnaire_stock',NULL,'critique');
    PERFORM public.creer_notification('Rupture de stock — '||NEW.titre,
      'Stock épuisé','erreur','stock','produits',NEW.produit_id,NEW.reference,
      '/stock','responsable_magasinier',NULL,'critique');
  ELSIF v_seuil > 0 AND v_stock <= v_seuil AND COALESCE(OLD.stock,0) > v_seuil THEN
    PERFORM public.creer_notification('Stock faible — '||NEW.titre,
      'Stock '||v_stock||' ≤ seuil '||v_seuil,'alerte','stock','produits',NEW.produit_id,NEW.reference,
      '/stock','gestionnaire_stock',NULL,'haute');
  ELSIF v_stock > v_seuil AND COALESCE(OLD.stock,0) <= v_seuil THEN
    PERFORM public.creer_notification('Réapprovisionnement — '||NEW.titre,
      'Stock revenu à '||v_stock,'succes','stock','produits',NEW.produit_id,NEW.reference,
      '/stock','gestionnaire_stock',NULL,'normale');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_stock ON public.produits;
CREATE TRIGGER trg_notif_stock AFTER UPDATE OF stock ON public.produits
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_stock();

-- Achats
CREATE OR REPLACE FUNCTION public.trg_notif_achats() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.creer_notification('Nouvel achat — '||COALESCE(NEW.reference,''),
      COALESCE(NEW.fournisseur_nom,''),'info','achats','achats',NEW.achat_id,NEW.reference,
      '/achats/'||NEW.achat_id,'gestionnaire_stock',NULL,'normale');
  ELSIF TG_OP='UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut AND NEW.statut='recu' THEN
    PERFORM public.creer_notification('Marchandises reçues — '||COALESCE(NEW.reference,''),
      COALESCE(NEW.fournisseur_nom,''),'succes','achats','achats',NEW.achat_id,NEW.reference,
      '/achats/'||NEW.achat_id,'gestionnaire_stock',NULL,'normale');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_achats ON public.achats;
CREATE TRIGGER trg_notif_achats AFTER INSERT OR UPDATE ON public.achats
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_achats();

-- Congés
CREATE OR REPLACE FUNCTION public.trg_notif_conges() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.creer_notification('Nouvelle demande de congé',
      'Du '||NEW.date_debut::text||' au '||NEW.date_fin::text,
      'info','rh','conges',NEW.conge_id,NULL,'/conges','directeur_general',NULL,'normale');
  ELSIF TG_OP='UPDATE' AND OLD.statut IS DISTINCT FROM NEW.statut THEN
    IF NEW.statut='approuve' OR NEW.statut='valide' THEN
      PERFORM public.creer_notification('Congé validé',
        'Du '||NEW.date_debut::text||' au '||NEW.date_fin::text,
        'succes','rh','conges',NEW.conge_id,NULL,'/conges','directeur_general',NULL,'normale');
    ELSIF NEW.statut='refuse' THEN
      PERFORM public.creer_notification('Congé refusé',
        'Du '||NEW.date_debut::text||' au '||NEW.date_fin::text,
        'alerte','rh','conges',NEW.conge_id,NULL,'/conges','directeur_general',NULL,'normale');
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_conges ON public.conges;
CREATE TRIGGER trg_notif_conges AFTER INSERT OR UPDATE ON public.conges
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_conges();

-- Absences
CREATE OR REPLACE FUNCTION public.trg_notif_absences() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.creer_notification('Nouvelle absence enregistrée',
    'Date: '||COALESCE(NEW.date_debut::text,''),
    'info','rh','absences',NEW.absence_id,NULL,'/absences','directeur_general',NULL,'normale');
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_notif_absences ON public.absences;
CREATE TRIGGER trg_notif_absences AFTER INSERT ON public.absences
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_absences();

-- Rôles utilisateurs (admin)
CREATE OR REPLACE FUNCTION public.trg_notif_user_roles() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    PERFORM public.creer_notification('Nouveau rôle attribué',
      'Rôle: '||NEW.role::text,'info','administration','user_roles',NEW.id,NULL,
      '/roles-permissions','super_admin',NULL,'normale');
  ELSIF TG_OP='DELETE' THEN
    PERFORM public.creer_notification('Rôle retiré',
      'Rôle: '||OLD.role::text,'alerte','administration','user_roles',OLD.id,NULL,
      '/roles-permissions','super_admin',NULL,'haute');
  END IF;
  RETURN COALESCE(NEW,OLD);
END $$;
DROP TRIGGER IF EXISTS trg_notif_user_roles ON public.user_roles;
CREATE TRIGGER trg_notif_user_roles AFTER INSERT OR DELETE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.trg_notif_user_roles();
