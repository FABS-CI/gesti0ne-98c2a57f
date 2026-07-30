
-- ============================================================
-- RBAC v3 — reconstruction complète du moteur de sécurité
-- ============================================================

-- 1. MODULES
CREATE TABLE public.rbac3_modules (
  code text PRIMARY KEY,
  label text NOT NULL,
  groupe text NOT NULL DEFAULT 'Général',
  ordre int NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.rbac3_modules TO authenticated;
GRANT ALL ON public.rbac3_modules TO service_role;
ALTER TABLE public.rbac3_modules ENABLE ROW LEVEL SECURITY;

-- 2. ACTIONS
CREATE TABLE public.rbac3_actions (
  code text PRIMARY KEY,
  label text NOT NULL,
  ordre int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.rbac3_actions TO authenticated;
GRANT ALL ON public.rbac3_actions TO service_role;
ALTER TABLE public.rbac3_actions ENABLE ROW LEVEL SECURITY;

-- 3. PERMISSIONS (module.action)
CREATE TABLE public.rbac3_permissions (
  code text PRIMARY KEY,
  module_code text NOT NULL REFERENCES public.rbac3_modules(code) ON DELETE CASCADE,
  action_code text NOT NULL REFERENCES public.rbac3_actions(code) ON DELETE CASCADE,
  label text NOT NULL,
  sensible boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (module_code, action_code)
);
GRANT SELECT ON public.rbac3_permissions TO authenticated;
GRANT ALL ON public.rbac3_permissions TO service_role;
ALTER TABLE public.rbac3_permissions ENABLE ROW LEVEL SECURITY;

-- 4. ROLES
CREATE TABLE public.rbac3_roles (
  code text PRIMARY KEY,
  label text NOT NULL,
  description text,
  statut text NOT NULL DEFAULT 'actif' CHECK (statut IN ('brouillon','actif','archive')),
  portee_globale boolean NOT NULL DEFAULT false,
  systeme boolean NOT NULL DEFAULT false,
  ordre int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.rbac3_roles TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.rbac3_roles TO authenticated;
GRANT ALL ON public.rbac3_roles TO service_role;
ALTER TABLE public.rbac3_roles ENABLE ROW LEVEL SECURITY;

-- 5. MATRICE role x permission
CREATE TABLE public.rbac3_role_permissions (
  role_code text NOT NULL REFERENCES public.rbac3_roles(code) ON DELETE CASCADE,
  perm_code text NOT NULL REFERENCES public.rbac3_permissions(code) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_code, perm_code)
);
GRANT SELECT, INSERT, DELETE ON public.rbac3_role_permissions TO authenticated;
GRANT ALL ON public.rbac3_role_permissions TO service_role;
ALTER TABLE public.rbac3_role_permissions ENABLE ROW LEVEL SECURITY;

-- 6. AFFECTATIONS utilisateur x role
CREATE TABLE public.rbac3_user_roles (
  user_id uuid NOT NULL,
  role_code text NOT NULL REFERENCES public.rbac3_roles(code) ON DELETE CASCADE,
  assigned_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_code)
);
CREATE INDEX idx_rbac3_user_roles_user ON public.rbac3_user_roles(user_id);
GRANT SELECT, INSERT, DELETE ON public.rbac3_user_roles TO authenticated;
GRANT ALL ON public.rbac3_user_roles TO service_role;
ALTER TABLE public.rbac3_user_roles ENABLE ROW LEVEL SECURITY;

-- 7. JOURNAL D'AUDIT (append-only)
CREATE TABLE public.rbac3_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acteur_id uuid,
  acteur_email text,
  action text NOT NULL,
  cible_type text NOT NULL,
  cible_id text,
  role_code text,
  perm_code text,
  ancienne_valeur jsonb,
  nouvelle_valeur jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_rbac3_audit_created ON public.rbac3_audit(created_at DESC);
GRANT SELECT, INSERT ON public.rbac3_audit TO authenticated;
GRANT SELECT, INSERT ON public.rbac3_audit TO service_role;
ALTER TABLE public.rbac3_audit ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEED : modules, actions, permissions
-- ============================================================
INSERT INTO public.rbac3_modules (code, label, groupe, ordre) VALUES
  ('tableau_bord','Tableau de bord','Pilotage',10),
  ('catalogue','Catalogue','Référentiel',20),
  ('produits','Produits','Référentiel',30),
  ('clients','Clients','Référentiel',40),
  ('fournisseurs','Fournisseurs','Référentiel',50),
  ('ventes','Ventes','Ventes',60),
  ('devis','Devis / Proformas','Ventes',70),
  ('commandes','Commandes','Ventes',80),
  ('factures','Factures','Ventes',90),
  ('paiements','Paiements','Ventes',100),
  ('retours','Retours','Ventes',110),
  ('achats','Achats','Achats',120),
  ('stocks','Stocks','Logistique',130),
  ('inventaires','Inventaires','Logistique',140),
  ('depots','Dépôts','Logistique',150),
  ('logistique','Logistique','Logistique',160),
  ('comptabilite','Comptabilité','Finance',170),
  ('banque','Banque','Finance',180),
  ('caisse','Caisse','Finance',190),
  ('rh','Ressources humaines','RH',200),
  ('rapports','Rapports','Pilotage',210),
  ('parametres','Paramètres','Système',220),
  ('administration','Administration','Système',230),
  ('audit','Audit','Système',240);

INSERT INTO public.rbac3_actions (code, label, ordre) VALUES
  ('lire','Lecture',10),
  ('creer','Création',20),
  ('modifier','Modification',30),
  ('supprimer','Suppression',40),
  ('valider','Validation',50),
  ('annuler','Annulation',60),
  ('imprimer','Impression',70),
  ('exporter','Export',80);

INSERT INTO public.rbac3_permissions (code, module_code, action_code, label, sensible)
SELECT m.code || '.' || a.code, m.code, a.code, a.label || ' — ' || m.label,
       a.code IN ('supprimer','valider','annuler')
FROM public.rbac3_modules m CROSS JOIN public.rbac3_actions a;

-- ============================================================
-- SEED : rôles
-- ============================================================
INSERT INTO public.rbac3_roles (code, label, description, portee_globale, systeme, ordre) VALUES
  ('super_admin','Super Administrateur','Portée globale sur tous les services, dépôts et départements',true,true,10),
  ('admin','Administrateur','Administration fonctionnelle, périmètre limité',false,true,20),
  ('directeur_general','Directeur Général','Pilotage et consultation globale des opérations',true,false,30),
  ('directeur_commercial','Directeur Commercial','Pilotage du cycle de vente',false,false,40),
  ('comptable','Comptable','Comptabilité, banque, caisse et facturation',false,false,50),
  ('assistante_comptable','Assistante Comptable','Saisie comptable et suivi des règlements',false,false,60),
  ('responsable_magasin','Responsable Magasin','Responsable d''un ou plusieurs dépôts',false,false,70),
  ('gestionnaire_stock','Gestionnaire de Stock','Mouvements et inventaires de stock',false,false,80),
  ('service_logistique','Service Logistique','Préparation, colisage, tournées et livraisons',false,false,90),
  ('rh','Ressources Humaines','Gestion du personnel et de la paie',false,false,100),
  ('secretariat','Secrétariat','Saisie et suivi administratif',false,false,110),
  ('commercial','Commercial','Prospection, devis et commandes clients',false,false,120);

-- ============================================================
-- SEED : matrice de permissions par défaut
-- ============================================================
-- super_admin : tout
INSERT INTO public.rbac3_role_permissions (role_code, perm_code)
SELECT 'super_admin', code FROM public.rbac3_permissions;

WITH defaut(role_code, modules, actions) AS (
  VALUES
    ('admin',
      ARRAY['tableau_bord','catalogue','produits','clients','fournisseurs','ventes','devis','commandes','factures','paiements','retours','achats','stocks','inventaires','depots','logistique','rapports','parametres','administration','audit'],
      ARRAY['lire','creer','modifier','valider','annuler','imprimer','exporter']),
    ('directeur_general',
      ARRAY['tableau_bord','catalogue','produits','clients','fournisseurs','ventes','devis','commandes','factures','paiements','retours','achats','stocks','inventaires','depots','logistique','comptabilite','banque','caisse','rh','rapports','audit'],
      ARRAY['lire','valider','annuler','imprimer','exporter']),
    ('directeur_commercial',
      ARRAY['tableau_bord','catalogue','produits','clients','ventes','devis','commandes','factures','paiements','retours','rapports'],
      ARRAY['lire','creer','modifier','supprimer','valider','annuler','imprimer','exporter']),
    ('comptable',
      ARRAY['tableau_bord','clients','fournisseurs','factures','paiements','retours','achats','comptabilite','banque','caisse','rapports'],
      ARRAY['lire','creer','modifier','valider','annuler','imprimer','exporter']),
    ('assistante_comptable',
      ARRAY['tableau_bord','clients','fournisseurs','factures','paiements','comptabilite','banque','caisse'],
      ARRAY['lire','creer','modifier','imprimer','exporter']),
    ('responsable_magasin',
      ARRAY['tableau_bord','catalogue','produits','stocks','inventaires','depots','logistique','achats','retours','rapports'],
      ARRAY['lire','creer','modifier','valider','annuler','imprimer','exporter']),
    ('gestionnaire_stock',
      ARRAY['tableau_bord','catalogue','produits','stocks','inventaires','depots'],
      ARRAY['lire','creer','modifier','imprimer','exporter']),
    ('service_logistique',
      ARRAY['tableau_bord','commandes','logistique','depots','stocks','retours'],
      ARRAY['lire','creer','modifier','valider','imprimer','exporter']),
    ('rh',
      ARRAY['tableau_bord','rh','rapports'],
      ARRAY['lire','creer','modifier','supprimer','valider','imprimer','exporter']),
    ('secretariat',
      ARRAY['tableau_bord','clients','devis','commandes','factures'],
      ARRAY['lire','creer','imprimer']),
    ('commercial',
      ARRAY['tableau_bord','clients','produits','catalogue','devis','commandes','factures','paiements','retours'],
      ARRAY['lire','creer','modifier','imprimer'])
)
INSERT INTO public.rbac3_role_permissions (role_code, perm_code)
SELECT d.role_code, p.code
FROM defaut d
JOIN public.rbac3_permissions p
  ON p.module_code = ANY(d.modules) AND p.action_code = ANY(d.actions)
ON CONFLICT DO NOTHING;

-- ============================================================
-- REPRISE des affectations utilisateurs (aucune perte d'accès)
-- ============================================================
INSERT INTO public.rbac3_user_roles (user_id, role_code)
SELECT DISTINCT ur.user_id,
  CASE ur.role_code
    WHEN 'responsable_magasinier' THEN 'responsable_magasin'
    WHEN 'assistante' THEN 'secretariat'
    ELSE ur.role_code
  END
FROM public.rbac2_user_roles ur
WHERE CASE ur.role_code
        WHEN 'responsable_magasinier' THEN 'responsable_magasin'
        WHEN 'assistante' THEN 'secretariat'
        ELSE ur.role_code
      END IN (SELECT code FROM public.rbac3_roles)
ON CONFLICT DO NOTHING;

-- ============================================================
-- MOTEUR CENTRAL
-- ============================================================
CREATE OR REPLACE FUNCTION public.rbac3_is_global(_user_id uuid DEFAULT auth.uid())
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rbac3_user_roles ur
    JOIN public.rbac3_roles r ON r.code = ur.role_code
    WHERE ur.user_id = _user_id AND r.statut = 'actif' AND r.portee_globale
  );
$$;

CREATE OR REPLACE FUNCTION public.rbac3_can(_perm text, _user_id uuid DEFAULT auth.uid())
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT _user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.rbac3_user_roles ur
    JOIN public.rbac3_roles r ON r.code = ur.role_code AND r.statut = 'actif'
    JOIN public.rbac3_role_permissions rp ON rp.role_code = ur.role_code
    WHERE ur.user_id = _user_id AND rp.perm_code = _perm
  );
$$;

CREATE OR REPLACE FUNCTION public.rbac3_assert(_perm text)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.rbac3_can(_perm) THEN
    RAISE EXCEPTION 'Accès refusé : permission % requise', _perm USING ERRCODE = '42501';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.rbac3_permissions_of(_user_id uuid DEFAULT auth.uid())
RETURNS TABLE(perm_code text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT DISTINCT rp.perm_code
  FROM public.rbac3_user_roles ur
  JOIN public.rbac3_roles r ON r.code = ur.role_code AND r.statut = 'actif'
  JOIN public.rbac3_role_permissions rp ON rp.role_code = ur.role_code
  WHERE ur.user_id = _user_id;
$$;

-- ============================================================
-- PÉRIMÈTRE (scope) : service, département, dépôt
-- ============================================================
CREATE OR REPLACE FUNCTION public.rbac3_scope_service(_service_id uuid, _user_id uuid DEFAULT auth.uid())
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.rbac3_is_global(_user_id)
      OR _service_id IS NULL
      OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = _user_id AND p.service_id = _service_id);
$$;

CREATE OR REPLACE FUNCTION public.rbac3_scope_departement(_departement_id uuid, _user_id uuid DEFAULT auth.uid())
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.rbac3_is_global(_user_id)
      OR _departement_id IS NULL
      OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = _user_id AND p.departement_id = _departement_id);
$$;

CREATE OR REPLACE FUNCTION public.rbac3_scope_depot(_depot_id uuid, _user_id uuid DEFAULT auth.uid())
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.rbac3_is_global(_user_id)
      OR _depot_id IS NULL
      OR EXISTS (SELECT 1 FROM public.user_depots ud WHERE ud.user_id = _user_id AND ud.depot_id = _depot_id)
      OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = _user_id AND p.depot_principal_id = _depot_id);
$$;

CREATE OR REPLACE FUNCTION public.rbac3_depots_autorises(_user_id uuid DEFAULT auth.uid())
RETURNS TABLE(depot_id uuid) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT d.depot_id FROM public.depots d WHERE public.rbac3_is_global(_user_id)
  UNION
  SELECT ud.depot_id FROM public.user_depots ud WHERE ud.user_id = _user_id
  UNION
  SELECT p.depot_principal_id FROM public.profiles p WHERE p.id = _user_id AND p.depot_principal_id IS NOT NULL;
$$;

-- ============================================================
-- POLICIES RLS du socle
-- ============================================================
CREATE POLICY "catalogue lisible" ON public.rbac3_modules FOR SELECT TO authenticated USING (true);
CREATE POLICY "catalogue lisible" ON public.rbac3_actions FOR SELECT TO authenticated USING (true);
CREATE POLICY "catalogue lisible" ON public.rbac3_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "roles lisibles" ON public.rbac3_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "roles administrables" ON public.rbac3_roles FOR ALL TO authenticated
  USING (public.rbac3_can('administration.modifier')) WITH CHECK (public.rbac3_can('administration.modifier'));

CREATE POLICY "matrice lisible" ON public.rbac3_role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "matrice modifiable" ON public.rbac3_role_permissions FOR INSERT TO authenticated
  WITH CHECK (public.rbac3_can('administration.modifier'));
CREATE POLICY "matrice retirable" ON public.rbac3_role_permissions FOR DELETE TO authenticated
  USING (public.rbac3_can('administration.modifier'));

CREATE POLICY "mes roles ou admin" ON public.rbac3_user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.rbac3_can('administration.lire'));
CREATE POLICY "affectation admin" ON public.rbac3_user_roles FOR INSERT TO authenticated
  WITH CHECK (public.rbac3_can('administration.modifier'));
CREATE POLICY "retrait admin" ON public.rbac3_user_roles FOR DELETE TO authenticated
  USING (public.rbac3_can('administration.modifier'));

-- audit append-only : aucune policy UPDATE/DELETE n'est créée
CREATE POLICY "audit lisible" ON public.rbac3_audit FOR SELECT TO authenticated
  USING (public.rbac3_can('audit.lire'));
CREATE POLICY "audit insertion" ON public.rbac3_audit FOR INSERT TO authenticated WITH CHECK (true);
REVOKE UPDATE, DELETE ON public.rbac3_audit FROM authenticated, anon, service_role;

-- ============================================================
-- TRIGGERS D'AUDIT
-- ============================================================
CREATE OR REPLACE FUNCTION public.rbac3_trace()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  SELECT email INTO v_email FROM public.profiles WHERE id = auth.uid();
  INSERT INTO public.rbac3_audit (acteur_id, acteur_email, action, cible_type, cible_id,
                                  role_code, perm_code, ancienne_valeur, nouvelle_valeur)
  VALUES (
    auth.uid(), v_email, TG_OP, TG_TABLE_NAME,
    COALESCE(
      to_jsonb(COALESCE(NEW, OLD)) ->> 'code',
      to_jsonb(COALESCE(NEW, OLD)) ->> 'user_id'),
    to_jsonb(COALESCE(NEW, OLD)) ->> 'role_code',
    to_jsonb(COALESCE(NEW, OLD)) ->> 'perm_code',
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_rbac3_roles_audit AFTER INSERT OR UPDATE OR DELETE ON public.rbac3_roles
  FOR EACH ROW EXECUTE FUNCTION public.rbac3_trace();
CREATE TRIGGER trg_rbac3_role_perms_audit AFTER INSERT OR DELETE ON public.rbac3_role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.rbac3_trace();
CREATE TRIGGER trg_rbac3_user_roles_audit AFTER INSERT OR DELETE ON public.rbac3_user_roles
  FOR EACH ROW EXECUTE FUNCTION public.rbac3_trace();

CREATE OR REPLACE FUNCTION public.rbac3_touch()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;
CREATE TRIGGER trg_rbac3_roles_touch BEFORE UPDATE ON public.rbac3_roles
  FOR EACH ROW EXECUTE FUNCTION public.rbac3_touch();
CREATE TRIGGER trg_rbac3_modules_touch BEFORE UPDATE ON public.rbac3_modules
  FOR EACH ROW EXECUTE FUNCTION public.rbac3_touch();

REVOKE EXECUTE ON FUNCTION public.rbac3_can(text, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rbac3_is_global(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rbac3_permissions_of(uuid) FROM anon;
