
-- ============================================================
-- RBAC v2 — Fondations : catalogue permissions, rôles paramétrables,
-- matrice role×permission, assignations utilisateurs, audit.
-- ============================================================

-- 1) Catalogue des permissions (statique, alimenté par seed)
CREATE TABLE IF NOT EXISTS public.rbac_permissions (
  code text PRIMARY KEY,
  module text NOT NULL,
  sous_module text,
  action text NOT NULL,
  libelle text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.rbac_permissions TO authenticated;
GRANT ALL ON public.rbac_permissions TO service_role;
ALTER TABLE public.rbac_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac_permissions readable by authenticated"
  ON public.rbac_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac_permissions writable by super_admin"
  ON public.rbac_permissions FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

-- 2) Rôles paramétrables
CREATE TABLE IF NOT EXISTS public.rbac_roles (
  role_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  libelle text NOT NULL,
  description text,
  actif boolean NOT NULL DEFAULT true,
  systeme boolean NOT NULL DEFAULT false,
  hierite_de uuid REFERENCES public.rbac_roles(role_id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rbac_roles_code ON public.rbac_roles(code);
GRANT SELECT ON public.rbac_roles TO authenticated;
GRANT ALL ON public.rbac_roles TO service_role;
ALTER TABLE public.rbac_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac_roles readable by authenticated"
  ON public.rbac_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac_roles writable by super_admin"
  ON public.rbac_roles FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));
CREATE TRIGGER trg_rbac_roles_updated
  BEFORE UPDATE ON public.rbac_roles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 3) Matrice role × permission
CREATE TABLE IF NOT EXISTS public.rbac_role_permissions (
  role_id uuid NOT NULL REFERENCES public.rbac_roles(role_id) ON DELETE CASCADE,
  permission_code text NOT NULL REFERENCES public.rbac_permissions(code) ON DELETE CASCADE,
  accorde boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_code)
);
CREATE INDEX idx_rbac_rp_role ON public.rbac_role_permissions(role_id);
CREATE INDEX idx_rbac_rp_perm ON public.rbac_role_permissions(permission_code);
GRANT SELECT ON public.rbac_role_permissions TO authenticated;
GRANT ALL ON public.rbac_role_permissions TO service_role;
ALTER TABLE public.rbac_role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac_rp readable by authenticated"
  ON public.rbac_role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac_rp writable by super_admin"
  ON public.rbac_role_permissions FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

-- 4) Assignation user ↔ rôle paramétrable (v2, parallèle à user_roles)
CREATE TABLE IF NOT EXISTS public.rbac_user_roles (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES public.rbac_roles(role_id) ON DELETE CASCADE,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by uuid REFERENCES auth.users(id),
  PRIMARY KEY (user_id, role_id)
);
CREATE INDEX idx_rbac_ur_user ON public.rbac_user_roles(user_id);
GRANT SELECT ON public.rbac_user_roles TO authenticated;
GRANT ALL ON public.rbac_user_roles TO service_role;
ALTER TABLE public.rbac_user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac_ur self read"
  ON public.rbac_user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'::app_role));
CREATE POLICY "rbac_ur writable by super_admin"
  ON public.rbac_user_roles FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::app_role));

-- 5) Journal d'audit RBAC
CREATE TABLE IF NOT EXISTS public.rbac_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  user_email text,
  role_id uuid,
  role_code text,
  action text NOT NULL, -- create/update/delete/perm_add/perm_remove/assign/unassign
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rbac_audit_role ON public.rbac_audit_log(role_id);
CREATE INDEX idx_rbac_audit_date ON public.rbac_audit_log(created_at DESC);
GRANT SELECT, INSERT ON public.rbac_audit_log TO authenticated;
GRANT ALL ON public.rbac_audit_log TO service_role;
ALTER TABLE public.rbac_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac_audit read super_admin"
  ON public.rbac_audit_log FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::app_role));
CREATE POLICY "rbac_audit insert authenticated"
  ON public.rbac_audit_log FOR INSERT TO authenticated
  WITH CHECK (true);

-- ============================================================
-- Fonctions
-- ============================================================

-- Résout la chaîne d'héritage d'un rôle (rôle + ancêtres)
CREATE OR REPLACE FUNCTION public.rbac_role_ancestors(_role_id uuid)
RETURNS TABLE(role_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  WITH RECURSIVE anc AS (
    SELECT r.role_id, r.hierite_de FROM public.rbac_roles r WHERE r.role_id = _role_id
    UNION ALL
    SELECT r.role_id, r.hierite_de
    FROM public.rbac_roles r
    JOIN anc ON anc.hierite_de = r.role_id
  )
  SELECT role_id FROM anc;
$$;

-- Liste toutes les permissions accordées à un user (rôles v2 + rôles legacy mappés)
CREATE OR REPLACE FUNCTION public.list_user_permissions(_user_id uuid)
RETURNS TABLE(permission_code text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  -- Super admin (legacy) : toutes les permissions
  SELECT p.code FROM public.rbac_permissions p
  WHERE EXISTS (SELECT 1 FROM public.user_roles ur
                WHERE ur.user_id = _user_id AND ur.role = 'super_admin'::app_role)
     OR EXISTS (SELECT 1 FROM public.rbac_user_roles ur
                JOIN public.rbac_roles r ON r.role_id = ur.role_id
                WHERE ur.user_id = _user_id AND r.code = 'super_admin' AND r.actif)
  UNION
  -- Permissions accordées via rôles v2 (avec héritage)
  SELECT DISTINCT rp.permission_code
  FROM public.rbac_user_roles ur
  JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id AND rp.accorde = true
  UNION
  -- Rétro-compat : mapping legacy user_roles → rbac_roles (par code)
  SELECT DISTINCT rp.permission_code
  FROM public.user_roles ur
  JOIN public.rbac_roles r ON r.code = ur.role::text AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id AND rp.accorde = true;
$$;
GRANT EXECUTE ON FUNCTION public.list_user_permissions(uuid) TO authenticated;

-- Vérifie une permission spécifique
CREATE OR REPLACE FUNCTION public.has_permission_v2(_user_id uuid, _perm text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.list_user_permissions(_user_id) p WHERE p.permission_code = _perm
  );
$$;
GRANT EXECUTE ON FUNCTION public.has_permission_v2(uuid, text) TO authenticated;

-- Assertion utilisable dans les RPC
CREATE OR REPLACE FUNCTION public.assert_permission(_perm text)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_permission_v2(auth.uid(), _perm) THEN
    RAISE EXCEPTION 'Permission refusée: %', _perm USING ERRCODE = '42501';
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.assert_permission(text) TO authenticated;

-- Trigger audit sur rbac_role_permissions
CREATE OR REPLACE FUNCTION public.trg_rbac_audit_rp()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text; v_code text;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  IF TG_OP = 'INSERT' THEN
    SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = NEW.role_id;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (auth.uid(), v_email, NEW.role_id, v_code,
      CASE WHEN NEW.accorde THEN 'perm_add' ELSE 'perm_remove' END,
      jsonb_build_object('permission', NEW.permission_code, 'accorde', NEW.accorde));
  ELSIF TG_OP = 'UPDATE' AND OLD.accorde IS DISTINCT FROM NEW.accorde THEN
    SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = NEW.role_id;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (auth.uid(), v_email, NEW.role_id, v_code,
      CASE WHEN NEW.accorde THEN 'perm_add' ELSE 'perm_remove' END,
      jsonb_build_object('permission', NEW.permission_code, 'accorde', NEW.accorde));
  ELSIF TG_OP = 'DELETE' THEN
    SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = OLD.role_id;
    INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
    VALUES (auth.uid(), v_email, OLD.role_id, v_code, 'perm_remove',
      jsonb_build_object('permission', OLD.permission_code));
  END IF;
  RETURN COALESCE(NEW, OLD);
END; $$;

CREATE TRIGGER trg_rbac_rp_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.rbac_role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_rp();

-- Trigger audit sur rbac_user_roles (assignations)
CREATE OR REPLACE FUNCTION public.trg_rbac_audit_ur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text; v_code text; v_target uuid;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  v_target := COALESCE(NEW.user_id, OLD.user_id);
  SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = COALESCE(NEW.role_id, OLD.role_id);
  INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
  VALUES (auth.uid(), v_email, COALESCE(NEW.role_id, OLD.role_id), v_code,
    CASE WHEN TG_OP='INSERT' THEN 'assign' ELSE 'unassign' END,
    jsonb_build_object('target_user_id', v_target));
  RETURN COALESCE(NEW, OLD);
END; $$;

CREATE TRIGGER trg_rbac_ur_audit
  AFTER INSERT OR DELETE ON public.rbac_user_roles
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_ur();

-- ============================================================
-- SEED : rôles système + catalogue permissions + mapping initial
-- ============================================================

-- Rôles système (codes alignés avec l'enum app_role existant)
INSERT INTO public.rbac_roles(code, libelle, description, systeme, actif) VALUES
  ('super_admin', 'Super Administrateur', 'Accès total à toutes les fonctionnalités', true, true),
  ('directeur_general', 'Direction Générale', 'Direction générale', true, true),
  ('comptable', 'Comptabilité', 'Comptabilité et finances', true, true),
  ('directeur_commercial', 'Direction Commerciale', 'Direction commerciale', true, true),
  ('secretariat', 'Secrétariat', 'Secrétariat', true, true),
  ('assistante', 'Assistante', 'Assistante commerciale', true, true),
  ('gestionnaire_stock', 'Gestionnaire de Stock', 'Gestion des stocks', true, true),
  ('responsable_magasinier', 'Responsable Magasinier', 'Responsable du magasin', true, true),
  ('service_logistique', 'Service Logistique', 'Service logistique', true, true),
  ('rh', 'Ressources Humaines', 'Gestion RH', true, true)
ON CONFLICT (code) DO NOTHING;

-- Catalogue des permissions : (module, sous_module, action) × modules ERP
-- Action codes : voir, creer, modifier, supprimer, valider, annuler, imprimer,
-- telecharger, exporter_pdf, exporter_excel, importer, dupliquer, archiver,
-- restaurer, changer_statut, voir_prix, voir_couts, voir_marges, voir_stats,
-- voir_rapports, voir_historique, acceder_parametres, gerer_utilisateurs
INSERT INTO public.rbac_permissions(code, module, sous_module, action, libelle)
SELECT
  m.sous_module || '.' || a.action AS code,
  m.module,
  m.sous_module,
  a.action,
  m.libelle || ' — ' || a.libelle
FROM (VALUES
  ('Tableau de bord', 'dashboard', 'Tableau de bord'),
  ('Gestion commerciale', 'clients', 'Clients'),
  ('Gestion commerciale', 'prospects', 'Prospects'),
  ('Gestion commerciale', 'produits', 'Produits'),
  ('Gestion commerciale', 'tarifs', 'Tarifs'),
  ('Gestion commerciale', 'commandes', 'Commandes'),
  ('Gestion commerciale', 'proformas', 'Proformas'),
  ('Gestion commerciale', 'factures', 'Factures'),
  ('Gestion commerciale', 'avoirs', 'Avoirs'),
  ('Gestion commerciale', 'bons_livraison', 'Bons de livraison'),
  ('Gestion commerciale', 'colisage', 'Colisage'),
  ('Gestion commerciale', 'retours', 'Retours'),
  ('Gestion commerciale', 'specimens', 'Spécimens'),
  ('Stocks & logistique', 'stock', 'Stock'),
  ('Stocks & logistique', 'depots', 'Dépôts'),
  ('Stocks & logistique', 'transferts', 'Transferts'),
  ('Stocks & logistique', 'inventaires', 'Inventaires'),
  ('Stocks & logistique', 'incidents', 'Incidents'),
  ('Stocks & logistique', 'fournisseurs', 'Fournisseurs'),
  ('Stocks & logistique', 'achats', 'Achats'),
  ('Stocks & logistique', 'flotte', 'Flotte'),
  ('Stocks & logistique', 'tournees', 'Tournées'),
  ('Stocks & logistique', 'livraisons', 'Livraisons'),
  ('Stocks & logistique', 'expeditions', 'Expéditions'),
  ('Stocks & logistique', 'couts_logistiques', 'Coûts logistiques'),
  ('Finance', 'paiements', 'Paiements'),
  ('Finance', 'finances', 'Finances'),
  ('Finance', 'etat_compte_clients', 'États compte clients'),
  ('Comptabilité', 'comptabilite', 'Comptabilité'),
  ('Comptabilité', 'ecritures_comptables', 'Écritures comptables'),
  ('Comptabilité', 'plan_comptable', 'Plan comptable'),
  ('Comptabilité', 'balance', 'Balance'),
  ('Comptabilité', 'grand_livre', 'Grand livre'),
  ('Comptabilité', 'etats_comptables', 'États comptables'),
  ('Comptabilité', 'fec', 'FEC'),
  ('Comptabilité', 'fne', 'FNE'),
  ('Ressources humaines', 'employes', 'Employés'),
  ('Ressources humaines', 'departements', 'Départements'),
  ('Ressources humaines', 'fonctions', 'Fonctions'),
  ('Ressources humaines', 'contrats', 'Contrats'),
  ('Ressources humaines', 'conges', 'Congés'),
  ('Ressources humaines', 'absences', 'Absences'),
  ('Ressources humaines', 'missions', 'Missions'),
  ('Ressources humaines', 'evaluations', 'Évaluations'),
  ('Ressources humaines', 'paie', 'Paie'),
  ('Ressources humaines', 'bulletins', 'Bulletins de paie'),
  ('Rapports', 'rapports', 'Rapports'),
  ('Rapports', 'exports', 'Exports'),
  ('Rapports', 'bi_analytics', 'BI Analytics'),
  ('Administration', 'utilisateurs', 'Utilisateurs'),
  ('Administration', 'roles_permissions', 'Rôles & Permissions'),
  ('Administration', 'audit', 'Audit'),
  ('Administration', 'parametres', 'Paramètres'),
  ('Administration', 'backup', 'Sauvegardes'),
  ('Administration', 'notifications', 'Notifications'),
  ('Administration', 'documents', 'Documents'),
  ('Administration', 'modeles_documents', 'Modèles de documents'),
  ('Administration', 'workflows', 'Workflows'),
  ('Administration', 'integrations', 'Intégrations')
) AS m(module, sous_module, libelle)
CROSS JOIN (VALUES
  ('voir', 'Consulter'),
  ('creer', 'Créer'),
  ('modifier', 'Modifier'),
  ('supprimer', 'Supprimer'),
  ('valider', 'Valider'),
  ('annuler', 'Annuler'),
  ('imprimer', 'Imprimer'),
  ('telecharger', 'Télécharger'),
  ('exporter_pdf', 'Exporter PDF'),
  ('exporter_excel', 'Exporter Excel'),
  ('importer', 'Importer'),
  ('dupliquer', 'Dupliquer'),
  ('archiver', 'Archiver'),
  ('changer_statut', 'Changer de statut'),
  ('voir_prix', 'Voir les prix'),
  ('voir_couts', 'Voir les coûts'),
  ('voir_marges', 'Voir les marges'),
  ('voir_stats', 'Voir les statistiques'),
  ('voir_historique', 'Voir l''historique'),
  ('acceder_parametres', 'Accéder aux paramètres')
) AS a(action, libelle)
ON CONFLICT (code) DO NOTHING;

-- Mapping initial : accorder à chaque rôle les permissions "voir" de ses modules
-- (reflet de l'actuelle matrice de src/lib/permissions.ts — droits minimaux ;
-- l'administrateur affinera ensuite depuis l'UI).
-- Super admin → tout (géré dynamiquement par list_user_permissions, pas besoin de seed).

-- Comptable : commercial + finance + compta + RH lecture
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'comptable'
  AND p.sous_module IN (
    'clients','commandes','proformas','factures','avoirs','bons_livraison','retours',
    'paiements','finances','etat_compte_clients','comptabilite','ecritures_comptables',
    'plan_comptable','balance','grand_livre','etats_comptables','fec','fne',
    'employes','departements','fonctions','contrats','conges','absences','missions',
    'evaluations','paie','bulletins','rapports','exports','couts_logistiques',
    'tournees','produits','inventaires','dashboard'
  )
  AND p.action IN ('voir','creer','modifier','valider','annuler','imprimer','telecharger',
                   'exporter_pdf','exporter_excel','changer_statut','voir_prix',
                   'voir_stats','voir_historique','dupliquer')
ON CONFLICT DO NOTHING;

-- Directeur général : tout en lecture + validations
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'directeur_general'
  AND p.action IN ('voir','valider','annuler','imprimer','telecharger','exporter_pdf',
                   'exporter_excel','voir_prix','voir_couts','voir_marges','voir_stats',
                   'voir_historique','changer_statut')
ON CONFLICT DO NOTHING;

-- Directeur commercial : commercial complet + lecture stock
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'directeur_commercial'
  AND p.sous_module IN ('dashboard','clients','prospects','commandes','proformas','factures',
                        'bons_livraison','livraisons','specimens','produits','stock','rapports')
  AND p.action IN ('voir','creer','modifier','valider','annuler','imprimer','telecharger',
                   'exporter_pdf','changer_statut','voir_prix','voir_stats','voir_historique')
ON CONFLICT DO NOTHING;

-- Secrétariat / Assistante : saisie commandes/proformas/clients
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code IN ('secretariat','assistante')
  AND p.sous_module IN ('dashboard','clients','commandes','proformas','produits','etat_compte_clients')
  AND p.action IN ('voir','creer','modifier','imprimer','telecharger','exporter_pdf','voir_prix')
ON CONFLICT DO NOTHING;

-- Gestionnaire de stock : stock complet
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'gestionnaire_stock'
  AND p.sous_module IN ('dashboard','produits','stock','depots','transferts','inventaires',
                        'incidents','fournisseurs','achats','retours','specimens','colisage')
  AND p.action IN ('voir','creer','modifier','supprimer','valider','imprimer','telecharger',
                   'exporter_pdf','importer','changer_statut','voir_couts','voir_stats','voir_historique')
ON CONFLICT DO NOTHING;

-- Responsable magasinier : préparation
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'responsable_magasinier'
  AND p.sous_module IN ('dashboard','stock','depots','transferts','inventaires','colisage',
                        'incidents','commandes','bons_livraison','produits')
  AND p.action IN ('voir','creer','modifier','changer_statut','imprimer','telecharger','voir_historique')
ON CONFLICT DO NOTHING;

-- Service logistique : transport
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'service_logistique'
  AND p.sous_module IN ('dashboard','flotte','tournees','livraisons','expeditions',
                        'couts_logistiques','bons_livraison','colisage','incidents','rapports')
  AND p.action IN ('voir','creer','modifier','changer_statut','valider','imprimer','telecharger',
                   'exporter_pdf','voir_stats','voir_historique')
ON CONFLICT DO NOTHING;

-- RH : ressources humaines
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'rh'
  AND p.sous_module IN ('dashboard','employes','departements','fonctions','contrats',
                        'conges','absences','missions','evaluations','paie','bulletins')
  AND p.action IN ('voir','creer','modifier','supprimer','valider','imprimer','telecharger',
                   'exporter_pdf','changer_statut','voir_stats','voir_historique')
ON CONFLICT DO NOTHING;
