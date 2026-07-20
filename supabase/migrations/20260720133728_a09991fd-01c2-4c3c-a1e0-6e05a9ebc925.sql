
DROP FUNCTION IF EXISTS public.has_permission_v2(uuid, text);

CREATE TABLE public.rbac2_domains (
  code text PRIMARY KEY,
  label text NOT NULL,
  icon text,
  sort int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.rbac2_domains TO authenticated;
GRANT ALL ON public.rbac2_domains TO service_role;
ALTER TABLE public.rbac2_domains ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_domains read" ON public.rbac2_domains FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_domains write" ON public.rbac2_domains
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_modules (
  code text PRIMARY KEY,
  domain_code text NOT NULL REFERENCES public.rbac2_domains(code) ON DELETE CASCADE,
  label text NOT NULL,
  icon text,
  sort int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rbac2_modules_domain ON public.rbac2_modules(domain_code);
GRANT SELECT ON public.rbac2_modules TO authenticated;
GRANT ALL ON public.rbac2_modules TO service_role;
ALTER TABLE public.rbac2_modules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_modules read" ON public.rbac2_modules FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_modules write" ON public.rbac2_modules
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_resources (
  code text PRIMARY KEY,
  module_code text NOT NULL REFERENCES public.rbac2_modules(code) ON DELETE CASCADE,
  label text NOT NULL,
  kind text NOT NULL DEFAULT 'screen',
  route text,
  rpc text,
  sort int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rbac2_resources_module ON public.rbac2_resources(module_code);
GRANT SELECT ON public.rbac2_resources TO authenticated;
GRANT ALL ON public.rbac2_resources TO service_role;
ALTER TABLE public.rbac2_resources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_resources read" ON public.rbac2_resources FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_resources write" ON public.rbac2_resources
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_permissions (
  code text PRIMARY KEY,
  resource_code text NOT NULL REFERENCES public.rbac2_resources(code) ON DELETE CASCADE,
  action text NOT NULL,
  label text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rbac2_permissions_resource ON public.rbac2_permissions(resource_code);
CREATE INDEX idx_rbac2_permissions_action ON public.rbac2_permissions(action);
GRANT SELECT ON public.rbac2_permissions TO authenticated;
GRANT ALL ON public.rbac2_permissions TO service_role;
ALTER TABLE public.rbac2_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_permissions read" ON public.rbac2_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_permissions write" ON public.rbac2_permissions
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_perm_deps (
  perm_code text NOT NULL REFERENCES public.rbac2_permissions(code) ON DELETE CASCADE,
  requires_code text NOT NULL REFERENCES public.rbac2_permissions(code) ON DELETE CASCADE,
  PRIMARY KEY (perm_code, requires_code),
  CHECK (perm_code <> requires_code)
);
GRANT SELECT ON public.rbac2_perm_deps TO authenticated;
GRANT ALL ON public.rbac2_perm_deps TO service_role;
ALTER TABLE public.rbac2_perm_deps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_perm_deps read" ON public.rbac2_perm_deps FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_perm_deps write" ON public.rbac2_perm_deps
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_roles (
  code text PRIMARY KEY,
  label text NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT false,
  sort int NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.rbac2_roles TO authenticated;
GRANT ALL ON public.rbac2_roles TO service_role;
ALTER TABLE public.rbac2_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_roles read" ON public.rbac2_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_roles write" ON public.rbac2_roles
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));
CREATE TRIGGER trg_rbac2_roles_updated BEFORE UPDATE ON public.rbac2_roles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.rbac2_role_parents (
  role_code text NOT NULL REFERENCES public.rbac2_roles(code) ON DELETE CASCADE,
  parent_code text NOT NULL REFERENCES public.rbac2_roles(code) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_code, parent_code),
  CHECK (role_code <> parent_code)
);
GRANT SELECT ON public.rbac2_role_parents TO authenticated;
GRANT ALL ON public.rbac2_role_parents TO service_role;
ALTER TABLE public.rbac2_role_parents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_role_parents read" ON public.rbac2_role_parents FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_role_parents write" ON public.rbac2_role_parents
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_role_perms (
  role_code text NOT NULL REFERENCES public.rbac2_roles(code) ON DELETE CASCADE,
  perm_code text NOT NULL REFERENCES public.rbac2_permissions(code) ON DELETE CASCADE,
  granted boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_code, perm_code)
);
CREATE INDEX idx_rbac2_role_perms_perm ON public.rbac2_role_perms(perm_code);
GRANT SELECT ON public.rbac2_role_perms TO authenticated;
GRANT ALL ON public.rbac2_role_perms TO service_role;
ALTER TABLE public.rbac2_role_perms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_role_perms read" ON public.rbac2_role_perms FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac2_role_perms write" ON public.rbac2_role_perms
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_user_roles (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_code text NOT NULL REFERENCES public.rbac2_roles(code) ON DELETE CASCADE,
  granted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_code)
);
CREATE INDEX idx_rbac2_user_roles_user ON public.rbac2_user_roles(user_id);
CREATE INDEX idx_rbac2_user_roles_role ON public.rbac2_user_roles(role_code);
GRANT SELECT ON public.rbac2_user_roles TO authenticated;
GRANT ALL ON public.rbac2_user_roles TO service_role;
ALTER TABLE public.rbac2_user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_user_roles self read" ON public.rbac2_user_roles
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR has_role(auth.uid(), 'super_admin'::app_role));
CREATE POLICY "rbac2_user_roles write" ON public.rbac2_user_roles
  FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));

CREATE TABLE public.rbac2_audit (
  id bigserial PRIMARY KEY,
  actor_id uuid,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text NOT NULL,
  before jsonb,
  after jsonb,
  ip inet,
  at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rbac2_audit_target ON public.rbac2_audit(target_type, target_id);
CREATE INDEX idx_rbac2_audit_at ON public.rbac2_audit(at DESC);
GRANT SELECT ON public.rbac2_audit TO authenticated;
GRANT ALL ON public.rbac2_audit TO service_role;
ALTER TABLE public.rbac2_audit ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rbac2_audit read" ON public.rbac2_audit
  FOR SELECT TO authenticated
  USING (has_role(auth.uid(), 'super_admin'::app_role));

CREATE FUNCTION public.has_permission_v2(_user_id uuid, _perm_code text)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_has boolean;
  v_denied boolean;
BEGIN
  IF _user_id IS NULL OR _perm_code IS NULL THEN RETURN false; END IF;
  WITH RECURSIVE role_closure AS (
    SELECT role_code FROM public.rbac2_user_roles WHERE user_id = _user_id
    UNION
    SELECT p.parent_code FROM role_closure rc
      JOIN public.rbac2_role_parents p ON p.role_code = rc.role_code
  ),
  denials AS (
    SELECT 1 FROM public.rbac2_role_perms rp
      JOIN role_closure rc ON rc.role_code = rp.role_code
      WHERE rp.perm_code = _perm_code AND rp.granted = false
  ),
  grants_ AS (
    SELECT 1 FROM public.rbac2_role_perms rp
      JOIN role_closure rc ON rc.role_code = rp.role_code
      WHERE rp.perm_code = _perm_code AND rp.granted = true
  )
  SELECT EXISTS (SELECT 1 FROM denials), EXISTS (SELECT 1 FROM grants_)
  INTO v_denied, v_has;
  IF v_denied THEN RETURN false; END IF;
  RETURN COALESCE(v_has, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac2_audit_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_ip inet := inet_client_addr();
  v_target_id text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_target_id := COALESCE(to_jsonb(OLD)->>'code', to_jsonb(OLD)->>'role_code', to_jsonb(OLD)->>'user_id', to_jsonb(OLD)->>'perm_code', 'unknown');
    INSERT INTO public.rbac2_audit(actor_id, action, target_type, target_id, before, ip)
      VALUES (v_actor, TG_OP, TG_TABLE_NAME, v_target_id, to_jsonb(OLD), v_ip);
    RETURN OLD;
  ELSE
    v_target_id := COALESCE(to_jsonb(NEW)->>'code', to_jsonb(NEW)->>'role_code', to_jsonb(NEW)->>'user_id', to_jsonb(NEW)->>'perm_code', 'unknown');
    INSERT INTO public.rbac2_audit(actor_id, action, target_type, target_id, before, after, ip)
      VALUES (v_actor, TG_OP, TG_TABLE_NAME, v_target_id,
              CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) END, to_jsonb(NEW), v_ip);
    RETURN NEW;
  END IF;
END;
$$;

CREATE TRIGGER trg_audit_rbac2_roles AFTER INSERT OR UPDATE OR DELETE ON public.rbac2_roles
  FOR EACH ROW EXECUTE FUNCTION public.rbac2_audit_trigger();
CREATE TRIGGER trg_audit_rbac2_role_parents AFTER INSERT OR DELETE ON public.rbac2_role_parents
  FOR EACH ROW EXECUTE FUNCTION public.rbac2_audit_trigger();
CREATE TRIGGER trg_audit_rbac2_role_perms AFTER INSERT OR UPDATE OR DELETE ON public.rbac2_role_perms
  FOR EACH ROW EXECUTE FUNCTION public.rbac2_audit_trigger();
CREATE TRIGGER trg_audit_rbac2_user_roles AFTER INSERT OR DELETE ON public.rbac2_user_roles
  FOR EACH ROW EXECUTE FUNCTION public.rbac2_audit_trigger();

INSERT INTO public.rbac2_domains(code, label, icon, sort) VALUES
  ('dashboard','Tableau de bord','LayoutDashboard',10),
  ('commercial','Commercial','ShoppingCart',20),
  ('crm','CRM','Users',25),
  ('stocks','Stocks & Logistique','Warehouse',30),
  ('achats','Achats','Truck',40),
  ('finance','Finance','Wallet',50),
  ('comptabilite','Comptabilité','BookOpen',60),
  ('rh','Ressources humaines','UserCog',70),
  ('paie','Paie','Receipt',75),
  ('rapports','Rapports & BI','BarChart3',80),
  ('notifications','Notifications','Bell',85),
  ('administration','Administration','Shield',90),
  ('parametres','Paramètres','Settings',95),
  ('audit','Audit','FileSearch',97),
  ('backup','Sauvegardes','HardDriveDownload',99);

WITH mapping(module_code, domain_code, label, icon, sort) AS (
  VALUES
    ('dashboard','dashboard','Tableau de bord','LayoutDashboard',10),
    ('dashboard_direction','dashboard','Dashboard Direction','Crown',20),
    ('commandes','commercial','Commandes','ShoppingCart',10),
    ('proformas','commercial','Proformas','FileText',20),
    ('factures','commercial','Factures','Receipt',30),
    ('paiements','commercial','Paiements','CreditCard',40),
    ('retours','commercial','Retours','Undo2',50),
    ('specimens','commercial','Spécimens','BookMarked',60),
    ('etat_compte_clients','commercial','État de compte clients','ClipboardList',70),
    ('clients','crm','Clients','Users',10),
    ('produits','stocks','Produits','Package',10),
    ('depots','stocks','Dépôts','Warehouse',20),
    ('stock','stocks','Stock','Boxes',30),
    ('alertes_stock','stocks','Alertes stock','AlertTriangle',35),
    ('inventaires','stocks','Inventaires','ClipboardCheck',40),
    ('transferts','stocks','Transferts','ArrowLeftRight',50),
    ('bons_livraison','stocks','Bons de livraison','FileCheck2',60),
    ('colisage','stocks','Colisage','Boxes',70),
    ('colisage_responsables','stocks','Responsables colisage','UserCheck',75),
    ('expeditions','stocks','Expéditions','Send',80),
    ('livraisons','stocks','Livraisons','Truck',85),
    ('livraison_suivi','stocks','Suivi livraisons','MapPin',87),
    ('tournees','stocks','Tournées','Route',90),
    ('incidents','stocks','Incidents','AlertOctagon',92),
    ('couts_logistiques','stocks','Coûts logistiques','Calculator',93),
    ('flotte','stocks','Flotte','Car',94),
    ('missions','stocks','Missions','Briefcase',95),
    ('achats','achats','Achats','Truck',10),
    ('fournisseurs','achats','Fournisseurs','Building2',20),
    ('finances','finance','Finances','Wallet',10),
    ('comptabilite','comptabilite','Comptabilité','BookOpen',10),
    ('plan_comptable','comptabilite','Plan comptable','BookMarked',20),
    ('ecritures_comptables','comptabilite','Écritures comptables','FileText',30),
    ('grand_livre','comptabilite','Grand livre','Book',40),
    ('balance','comptabilite','Balance','Scale',50),
    ('exercices','comptabilite','Exercices','CalendarRange',60),
    ('fec','comptabilite','FEC','FileDown',70),
    ('fne','comptabilite','FNE','Landmark',80),
    ('employes','rh','Employés','Users',10),
    ('departements','rh','Départements','Building',20),
    ('fonctions','rh','Fonctions','Briefcase',30),
    ('contrats','rh','Contrats','FileText',40),
    ('absences','rh','Absences','CalendarX',50),
    ('conges','rh','Congés','Palmtree',60),
    ('evaluations','rh','Évaluations','Star',70),
    ('paie','paie','Bulletins de paie','Receipt',10),
    ('paie_rubriques','paie','Rubriques de paie','ListChecks',20),
    ('rapports','rapports','Rapports','FileBarChart',10),
    ('bi_analytics','rapports','BI & Analytics','BarChart3',20),
    ('notifications','notifications','Notifications','Bell',10),
    ('utilisateurs','administration','Utilisateurs','Users',10),
    ('roles_permissions','administration','Rôles & permissions','Shield',20),
    ('administration','administration','Administration système','Wrench',30),
    ('modeles_documents','administration','Modèles de documents','FileText',40),
    ('documents','administration','Documents','FolderOpen',50),
    ('parametres','parametres','Paramètres','Settings',10),
    ('audit','audit','Journal d''audit','FileSearch',10),
    ('backup','backup','Sauvegardes','HardDriveDownload',10)
)
INSERT INTO public.rbac2_modules(code, domain_code, label, icon, sort)
SELECT * FROM mapping;

INSERT INTO public.rbac2_resources(code, module_code, label, kind, sort)
SELECT DISTINCT
  p.module || ':' || COALESCE(p.sous_module, p.module),
  p.module,
  CASE WHEN p.sous_module IS NOT NULL
       THEN INITCAP(REPLACE(p.sous_module, '_', ' '))
       ELSE INITCAP(REPLACE(p.module, '_', ' ')) END,
  'screen', 100
FROM public.rbac_permissions p
WHERE p.module IN (SELECT code FROM public.rbac2_modules)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.rbac2_permissions(code, resource_code, action, label, description)
SELECT p.code, p.module || ':' || COALESCE(p.sous_module, p.module), p.action, p.libelle, p.description
FROM public.rbac_permissions p
WHERE p.module IN (SELECT code FROM public.rbac2_modules)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.rbac2_roles(code, label, description, is_system, sort)
SELECT code, libelle, description, systeme,
  CASE code
    WHEN 'super_admin' THEN 10 WHEN 'admin' THEN 20
    WHEN 'directeur_general' THEN 30 WHEN 'directeur_commercial' THEN 40
    WHEN 'manager' THEN 50 WHEN 'comptable' THEN 60
    WHEN 'assistante_comptable' THEN 65 WHEN 'commercial' THEN 70
    WHEN 'rh' THEN 80 WHEN 'responsable_magasinier' THEN 85
    WHEN 'gestionnaire_stock' THEN 87 WHEN 'service_logistique' THEN 88
    WHEN 'caissier' THEN 90 WHEN 'livreur' THEN 92
    WHEN 'secretariat' THEN 94 WHEN 'assistante' THEN 96
    WHEN 'auditeur' THEN 97 WHEN 'employe' THEN 100 ELSE 200 END
FROM public.rbac_roles
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.rbac2_role_parents(role_code, parent_code)
SELECT r.code, p.code
FROM public.rbac_roles r
JOIN public.rbac_roles p ON p.role_id = r.hierite_de
WHERE r.hierite_de IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO public.rbac2_role_perms(role_code, perm_code, granted)
SELECT r.code, rp.permission_code, rp.accorde
FROM public.rbac_role_permissions rp
JOIN public.rbac_roles r ON r.role_id = rp.role_id
JOIN public.rbac2_permissions p ON p.code = rp.permission_code
ON CONFLICT (role_code, perm_code) DO NOTHING;

INSERT INTO public.rbac2_user_roles(user_id, role_code, granted_by, granted_at)
SELECT ur.user_id, r.code, ur.assigned_by, ur.assigned_at
FROM public.rbac_user_roles ur
JOIN public.rbac_roles r ON r.role_id = ur.role_id
ON CONFLICT DO NOTHING;
