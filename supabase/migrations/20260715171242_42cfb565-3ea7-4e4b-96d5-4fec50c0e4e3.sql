-- Restore profiles and RBAC v2 compatibility after backend reset

-- Add missing enum value used by the app if absent
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'app_role'
      AND e.enumlabel = 'assistante_comptable'
  ) THEN
    ALTER TYPE public.app_role ADD VALUE 'assistante_comptable';
  END IF;
END $$;

-- Shared timestamp helper
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Profiles expected by the users/RBAC screens
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY,
  email text,
  nom_complet text,
  prenom text,
  telephone text,
  fonction text,
  departement text,
  avatar_url text,
  actif boolean NOT NULL DEFAULT true,
  mfa_enrolled_at timestamptz,
  mfa_required boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_self_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_self_update" ON public.profiles;
DROP POLICY IF EXISTS "Profiles users read own" ON public.profiles;
DROP POLICY IF EXISTS "Profiles users update own" ON public.profiles;
DROP POLICY IF EXISTS "Profiles super admins manage all" ON public.profiles;
CREATE POLICY "Profiles users read own"
  ON public.profiles FOR SELECT TO authenticated
  USING (auth.uid() = id OR public.has_role(auth.uid(), 'super_admin'::public.app_role));
CREATE POLICY "Profiles users update own"
  ON public.profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id OR public.has_role(auth.uid(), 'super_admin'::public.app_role))
  WITH CHECK (auth.uid() = id OR public.has_role(auth.uid(), 'super_admin'::public.app_role));
CREATE POLICY "Profiles super admins manage all"
  ON public.profiles FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::public.app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::public.app_role));
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Backfill existing auth accounts into profiles
INSERT INTO public.profiles (id, email, nom_complet, avatar_url, actif, created_at, updated_at)
SELECT
  u.id,
  u.email,
  COALESCE(
    NULLIF(u.raw_user_meta_data->>'nom_complet', ''),
    NULLIF(u.raw_user_meta_data->>'full_name', ''),
    NULLIF(u.raw_user_meta_data->>'name', ''),
    u.email
  ) AS nom_complet,
  NULLIF(u.raw_user_meta_data->>'avatar_url', '') AS avatar_url,
  true,
  COALESCE(u.created_at, now()),
  now()
FROM auth.users u
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  nom_complet = COALESCE(public.profiles.nom_complet, EXCLUDED.nom_complet),
  avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url),
  updated_at = now();

-- Bring rbac_roles from temporary reset schema to full v2 schema expected by app
ALTER TABLE public.rbac_roles ADD COLUMN IF NOT EXISTS role_id uuid;
UPDATE public.rbac_roles SET role_id = id WHERE role_id IS NULL AND id IS NOT NULL;
UPDATE public.rbac_roles SET role_id = gen_random_uuid() WHERE role_id IS NULL;
ALTER TABLE public.rbac_roles ALTER COLUMN role_id SET DEFAULT gen_random_uuid();
ALTER TABLE public.rbac_roles ALTER COLUMN role_id SET NOT NULL;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rbac_roles_role_id_key') THEN
    ALTER TABLE public.rbac_roles ADD CONSTRAINT rbac_roles_role_id_key UNIQUE (role_id);
  END IF;
END $$;
ALTER TABLE public.rbac_roles ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.rbac_roles ADD COLUMN IF NOT EXISTS systeme boolean NOT NULL DEFAULT false;
ALTER TABLE public.rbac_roles ADD COLUMN IF NOT EXISTS hierite_de uuid;
ALTER TABLE public.rbac_roles ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rbac_roles_hierite_de_fkey') THEN
    ALTER TABLE public.rbac_roles
      ADD CONSTRAINT rbac_roles_hierite_de_fkey
      FOREIGN KEY (hierite_de) REFERENCES public.rbac_roles(role_id) ON DELETE SET NULL;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_rbac_roles_code ON public.rbac_roles(code);
DROP TRIGGER IF EXISTS trg_rbac_roles_updated ON public.rbac_roles;
CREATE TRIGGER trg_rbac_roles_updated
  BEFORE UPDATE ON public.rbac_roles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP POLICY IF EXISTS "Authenticated read rbac_roles" ON public.rbac_roles;
DROP POLICY IF EXISTS "rbac_roles readable by authenticated" ON public.rbac_roles;
DROP POLICY IF EXISTS "rbac_roles writable by super_admin" ON public.rbac_roles;
CREATE POLICY "rbac_roles readable by authenticated"
  ON public.rbac_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac_roles writable by super_admin"
  ON public.rbac_roles FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::public.app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::public.app_role));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rbac_roles TO authenticated;
GRANT ALL ON public.rbac_roles TO service_role;

-- Compatibility for rbac_user_roles: old temporary column was rbac_role_id, app expects role_id
ALTER TABLE public.rbac_user_roles ADD COLUMN IF NOT EXISTS role_id uuid;
UPDATE public.rbac_user_roles SET role_id = rbac_role_id WHERE role_id IS NULL AND rbac_role_id IS NOT NULL;
DELETE FROM public.rbac_user_roles ur
WHERE ur.role_id IS NULL
   OR NOT EXISTS (SELECT 1 FROM public.rbac_roles r WHERE r.role_id = ur.role_id);
ALTER TABLE public.rbac_user_roles ALTER COLUMN role_id SET NOT NULL;
-- Let app/admin code insert role_id only; keep legacy rbac_role_id nullable for old reads if any.
ALTER TABLE public.rbac_user_roles ALTER COLUMN rbac_role_id DROP NOT NULL;
ALTER TABLE public.rbac_user_roles ADD COLUMN IF NOT EXISTS assigned_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.rbac_user_roles ADD COLUMN IF NOT EXISTS assigned_by uuid;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rbac_user_roles_role_id_fkey') THEN
    ALTER TABLE public.rbac_user_roles
      ADD CONSTRAINT rbac_user_roles_role_id_fkey
      FOREIGN KEY (role_id) REFERENCES public.rbac_roles(role_id) ON DELETE CASCADE;
  END IF;
END $$;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rbac_user_roles_user_role_unique') THEN
    ALTER TABLE public.rbac_user_roles ADD CONSTRAINT rbac_user_roles_user_role_unique UNIQUE (user_id, role_id);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_rbac_ur_user ON public.rbac_user_roles(user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rbac_user_roles TO authenticated;
GRANT ALL ON public.rbac_user_roles TO service_role;
DROP POLICY IF EXISTS "Users read own rbac assignments" ON public.rbac_user_roles;
DROP POLICY IF EXISTS "rbac_ur self read" ON public.rbac_user_roles;
DROP POLICY IF EXISTS "rbac_ur writable by super_admin" ON public.rbac_user_roles;
CREATE POLICY "rbac_ur self read"
  ON public.rbac_user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'::public.app_role));
CREATE POLICY "rbac_ur writable by super_admin"
  ON public.rbac_user_roles FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::public.app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::public.app_role));

-- Permission catalogue
CREATE TABLE IF NOT EXISTS public.rbac_permissions (
  code text PRIMARY KEY,
  module text NOT NULL,
  sous_module text,
  action text NOT NULL,
  libelle text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rbac_permissions TO authenticated;
GRANT ALL ON public.rbac_permissions TO service_role;
ALTER TABLE public.rbac_permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rbac_permissions readable by authenticated" ON public.rbac_permissions;
DROP POLICY IF EXISTS "rbac_permissions writable by super_admin" ON public.rbac_permissions;
CREATE POLICY "rbac_permissions readable by authenticated"
  ON public.rbac_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac_permissions writable by super_admin"
  ON public.rbac_permissions FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::public.app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::public.app_role));

-- Role x permission matrix
CREATE TABLE IF NOT EXISTS public.rbac_role_permissions (
  role_id uuid NOT NULL REFERENCES public.rbac_roles(role_id) ON DELETE CASCADE,
  permission_code text NOT NULL REFERENCES public.rbac_permissions(code) ON DELETE CASCADE,
  accorde boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_code)
);
CREATE INDEX IF NOT EXISTS idx_rbac_rp_role ON public.rbac_role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_rbac_rp_perm ON public.rbac_role_permissions(permission_code);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rbac_role_permissions TO authenticated;
GRANT ALL ON public.rbac_role_permissions TO service_role;
ALTER TABLE public.rbac_role_permissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rbac_rp readable by authenticated" ON public.rbac_role_permissions;
DROP POLICY IF EXISTS "rbac_rp writable by super_admin" ON public.rbac_role_permissions;
CREATE POLICY "rbac_rp readable by authenticated"
  ON public.rbac_role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "rbac_rp writable by super_admin"
  ON public.rbac_role_permissions FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::public.app_role))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'::public.app_role));

-- Audit log expected by admin functions
CREATE TABLE IF NOT EXISTS public.rbac_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  user_email text,
  role_id uuid,
  role_code text,
  action text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip text,
  user_agent text,
  avant jsonb,
  apres jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.rbac_audit_log ADD COLUMN IF NOT EXISTS user_agent text;
ALTER TABLE public.rbac_audit_log ADD COLUMN IF NOT EXISTS avant jsonb;
ALTER TABLE public.rbac_audit_log ADD COLUMN IF NOT EXISTS apres jsonb;
CREATE INDEX IF NOT EXISTS idx_rbac_audit_role ON public.rbac_audit_log(role_id);
CREATE INDEX IF NOT EXISTS idx_rbac_audit_date ON public.rbac_audit_log(created_at DESC);
GRANT SELECT, INSERT ON public.rbac_audit_log TO authenticated;
GRANT ALL ON public.rbac_audit_log TO service_role;
ALTER TABLE public.rbac_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rbac_audit read super_admin" ON public.rbac_audit_log;
DROP POLICY IF EXISTS "rbac_audit insert authenticated" ON public.rbac_audit_log;
CREATE POLICY "rbac_audit read super_admin"
  ON public.rbac_audit_log FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::public.app_role));
CREATE POLICY "rbac_audit insert authenticated"
  ON public.rbac_audit_log FOR INSERT TO authenticated
  WITH CHECK (true);

-- Seed/update system roles
INSERT INTO public.rbac_roles(code, libelle, description, systeme, actif) VALUES
  ('super_admin', 'Super Administrateur', 'Accès total à toutes les fonctionnalités', true, true),
  ('directeur_general', 'Direction Générale', 'Direction générale', true, true),
  ('comptable', 'Comptabilité', 'Comptabilité et finances', true, true),
  ('directeur_commercial', 'Direction Commerciale', 'Direction commerciale', true, true),
  ('secretariat', 'Secrétariat', 'Secrétariat', true, true),
  ('assistante', 'Assistante', 'Assistante commerciale', true, true),
  ('assistante_comptable', 'Assistante Comptable', 'Assistance comptable', true, true),
  ('gestionnaire_stock', 'Gestionnaire de Stock', 'Gestion des stocks', true, true),
  ('responsable_magasinier', 'Responsable Magasinier', 'Responsable du magasin', true, true),
  ('service_logistique', 'Service Logistique', 'Service logistique', true, true)
ON CONFLICT (code) DO UPDATE SET
  libelle = EXCLUDED.libelle,
  description = EXCLUDED.description,
  systeme = true,
  actif = true,
  updated_at = now();

-- Seed a practical ERP permission catalogue used by menus, guards and RBAC console
INSERT INTO public.rbac_permissions(code, module, sous_module, action, libelle, description) VALUES
  ('roles_permissions.voir', 'roles_permissions', null, 'voir', 'Voir rôles et permissions', null),
  ('roles_permissions.creer_role', 'roles_permissions', 'roles', 'creer', 'Créer un rôle', null),
  ('roles_permissions.modifier_role', 'roles_permissions', 'roles', 'modifier', 'Modifier un rôle', null),
  ('roles_permissions.supprimer_role', 'roles_permissions', 'roles', 'supprimer', 'Supprimer un rôle', null),
  ('roles_permissions.dupliquer_role', 'roles_permissions', 'roles', 'dupliquer', 'Dupliquer un rôle', null),
  ('roles_permissions.assigner_permission', 'roles_permissions', 'permissions', 'assigner', 'Attribuer une permission', null),
  ('roles_permissions.assigner_role_utilisateur', 'roles_permissions', 'utilisateurs', 'assigner', 'Attribuer un rôle à un utilisateur', null),
  ('utilisateurs.voir', 'utilisateurs', null, 'voir', 'Voir les utilisateurs', null),
  ('utilisateurs.creer', 'utilisateurs', null, 'creer', 'Créer un utilisateur', null),
  ('utilisateurs.modifier', 'utilisateurs', null, 'modifier', 'Modifier un utilisateur', null),
  ('utilisateurs.supprimer', 'utilisateurs', null, 'supprimer', 'Supprimer un utilisateur', null),
  ('utilisateurs.revoquer_role', 'utilisateurs', 'roles', 'revoquer', 'Retirer un rôle utilisateur', null),
  ('dashboard_personnel.voir', 'dashboard', 'personnel', 'voir', 'Voir le tableau de bord personnel', null),
  ('dashboard_metier.voir', 'dashboard', 'metier', 'voir', 'Voir le tableau de bord métier', null),
  ('dashboard_direction.voir', 'dashboard', 'direction', 'voir', 'Voir le tableau de bord direction', null),
  ('dashboard.voir_ca', 'dashboard', 'kpi', 'voir_ca', 'Voir le chiffre d’affaires', null),
  ('clients.voir', 'clients', null, 'voir', 'Voir les clients', null),
  ('clients.creer', 'clients', null, 'creer', 'Créer un client', null),
  ('clients.modifier', 'clients', null, 'modifier', 'Modifier un client', null),
  ('clients.supprimer', 'clients', null, 'supprimer', 'Supprimer un client', null),
  ('fournisseurs.voir', 'fournisseurs', null, 'voir', 'Voir les fournisseurs', null),
  ('fournisseurs.creer', 'fournisseurs', null, 'creer', 'Créer un fournisseur', null),
  ('fournisseurs.modifier', 'fournisseurs', null, 'modifier', 'Modifier un fournisseur', null),
  ('fournisseurs.supprimer', 'fournisseurs', null, 'supprimer', 'Supprimer un fournisseur', null),
  ('produits.voir', 'produits', null, 'voir', 'Voir les produits', null),
  ('produits.creer', 'produits', null, 'creer', 'Créer un produit', null),
  ('produits.modifier', 'produits', null, 'modifier', 'Modifier un produit', null),
  ('produits.supprimer', 'produits', null, 'supprimer', 'Supprimer un produit', null),
  ('stocks.voir', 'stocks', null, 'voir', 'Voir les stocks', null),
  ('stocks.modifier', 'stocks', null, 'modifier', 'Modifier les stocks', null),
  ('inventaires.voir', 'inventaires', null, 'voir', 'Voir les inventaires', null),
  ('inventaires.creer', 'inventaires', null, 'creer', 'Créer un inventaire', null),
  ('inventaires.valider', 'inventaires', null, 'valider', 'Valider un inventaire', null),
  ('inventaires.annuler', 'inventaires', null, 'annuler', 'Annuler un inventaire', null),
  ('commandes.voir', 'commandes', null, 'voir', 'Voir les commandes', null),
  ('commandes.creer', 'commandes', null, 'creer', 'Créer une commande', null),
  ('commandes.modifier', 'commandes', null, 'modifier', 'Modifier une commande', null),
  ('commandes.valider', 'commandes', null, 'valider', 'Valider une commande', null),
  ('commandes.supprimer', 'commandes', null, 'supprimer', 'Supprimer une commande', null),
  ('factures.voir', 'factures', null, 'voir', 'Voir les factures', null),
  ('factures.creer', 'factures', null, 'creer', 'Créer une facture', null),
  ('factures.modifier', 'factures', null, 'modifier', 'Modifier une facture', null),
  ('factures.supprimer', 'factures', null, 'supprimer', 'Supprimer une facture', null),
  ('proformas.voir', 'proformas', null, 'voir', 'Voir les proformas', null),
  ('proformas.creer', 'proformas', null, 'creer', 'Créer une proforma', null),
  ('proformas.modifier', 'proformas', null, 'modifier', 'Modifier une proforma', null),
  ('proformas.supprimer', 'proformas', null, 'supprimer', 'Supprimer une proforma', null),
  ('paiements.voir', 'paiements', null, 'voir', 'Voir les paiements', null),
  ('paiements.creer', 'paiements', null, 'creer', 'Créer un paiement', null),
  ('paiements.annuler', 'paiements', null, 'annuler', 'Annuler un paiement', null),
  ('achats.voir', 'achats', null, 'voir', 'Voir les achats', null),
  ('achats.creer', 'achats', null, 'creer', 'Créer un achat', null),
  ('achats.modifier', 'achats', null, 'modifier', 'Modifier un achat', null),
  ('achats.supprimer', 'achats', null, 'supprimer', 'Supprimer un achat', null),
  ('colisage.voir', 'colisage', null, 'voir', 'Voir le colisage', null),
  ('colisage.creer', 'colisage', null, 'creer', 'Créer un colisage', null),
  ('colisage.annuler', 'colisage', null, 'annuler', 'Annuler un colisage', null),
  ('colisage.supprimer', 'colisage', null, 'supprimer', 'Supprimer un colisage', null),
  ('livraison_suivi.voir', 'livraison_suivi', null, 'voir', 'Voir le suivi livraison', null),
  ('livraison_suivi.supprimer', 'livraison_suivi', null, 'supprimer', 'Supprimer un suivi livraison', null),
  ('tournees.voir', 'tournees', null, 'voir', 'Voir les tournées', null),
  ('tournees.creer', 'tournees', null, 'creer', 'Créer une tournée', null),
  ('tournees.valider', 'tournees', null, 'valider', 'Valider une tournée', null),
  ('tournees.annuler', 'tournees', null, 'annuler', 'Annuler une tournée', null),
  ('tournees.supprimer', 'tournees', null, 'supprimer', 'Supprimer une tournée', null),
  ('incidents.voir', 'incidents', null, 'voir', 'Voir les incidents', null),
  ('incidents.annuler', 'incidents', null, 'annuler', 'Annuler un incident', null),
  ('retours.voir', 'retours', null, 'voir', 'Voir les retours', null),
  ('retours.annuler', 'retours', null, 'annuler', 'Annuler un retour', null),
  ('specimens.voir', 'specimens', null, 'voir', 'Voir les spécimens', null),
  ('specimens.annuler', 'specimens', null, 'annuler', 'Annuler un spécimen', null),
  ('transferts.voir', 'transferts', null, 'voir', 'Voir les transferts', null),
  ('transferts.annuler', 'transferts', null, 'annuler', 'Annuler un transfert', null),
  ('employes.voir', 'employes', null, 'voir', 'Voir les employés', null),
  ('employes.supprimer', 'employes', null, 'supprimer', 'Supprimer un employé', null)
ON CONFLICT (code) DO UPDATE SET
  module = EXCLUDED.module,
  sous_module = EXCLUDED.sous_module,
  action = EXCLUDED.action,
  libelle = EXCLUDED.libelle,
  description = EXCLUDED.description;

-- Super admin gets every permission; management roles receive baseline dashboards
INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
CROSS JOIN public.rbac_permissions p
WHERE r.code = 'super_admin'
ON CONFLICT (role_id, permission_code) DO UPDATE SET accorde = true;

INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
FROM public.rbac_roles r
JOIN public.rbac_permissions p ON p.code IN ('dashboard_personnel.voir', 'dashboard_metier.voir')
WHERE r.code <> 'super_admin'
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- Ensure every current account is still super_admin in both legacy and RBAC v2 tables
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'super_admin'::public.app_role FROM auth.users
ON CONFLICT DO NOTHING;

INSERT INTO public.rbac_user_roles (user_id, role_id, rbac_role_id)
SELECT u.id, r.role_id, r.role_id
FROM auth.users u
CROSS JOIN public.rbac_roles r
WHERE r.code = 'super_admin'
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Permission functions used by guards and mutation pre-checks
CREATE OR REPLACE FUNCTION public.rbac_role_ancestors(_role_id uuid)
RETURNS TABLE(role_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
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
GRANT EXECUTE ON FUNCTION public.rbac_role_ancestors(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_user_permissions(_user_id uuid)
RETURNS TABLE(permission_code text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.code FROM public.rbac_permissions p
  WHERE EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = _user_id AND ur.role = 'super_admin'::public.app_role
  )
  OR EXISTS (
    SELECT 1
    FROM public.rbac_user_roles ur
    JOIN public.rbac_roles r ON r.role_id = ur.role_id
    WHERE ur.user_id = _user_id AND r.code = 'super_admin' AND r.actif
  )
  UNION
  SELECT DISTINCT rp.permission_code
  FROM public.rbac_user_roles ur
  JOIN public.rbac_roles r ON r.role_id = ur.role_id AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id AND rp.accorde = true
  UNION
  SELECT DISTINCT rp.permission_code
  FROM public.user_roles ur
  JOIN public.rbac_roles r ON r.code = ur.role::text AND r.actif
  JOIN LATERAL public.rbac_role_ancestors(r.role_id) anc ON true
  JOIN public.rbac_role_permissions rp ON rp.role_id = anc.role_id
  WHERE ur.user_id = _user_id AND rp.accorde = true;
$$;
GRANT EXECUTE ON FUNCTION public.list_user_permissions(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.has_permission_v2(_user_id uuid, _perm text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.list_user_permissions(_user_id) p WHERE p.permission_code = _perm
  );
$$;
GRANT EXECUTE ON FUNCTION public.has_permission_v2(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.assert_permission(_perm text)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifié' USING ERRCODE = '28000';
  END IF;
  IF NOT public.has_permission_v2(auth.uid(), _perm) THEN
    INSERT INTO public.rbac_audit_log(user_id, action, details)
    VALUES (auth.uid(), 'permission_denied', jsonb_build_object('permission', _perm, 'source', 'rpc'));
    RAISE EXCEPTION 'Permission refusée: %', _perm USING ERRCODE = '42501';
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.assert_permission(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.rbac_set_role_permission(_role_id uuid, _code text, _accorde boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('roles_permissions.assigner_permission');
  IF _accorde THEN
    INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
    VALUES (_role_id, _code, true)
    ON CONFLICT (role_id, permission_code) DO UPDATE SET accorde = true;
  ELSE
    DELETE FROM public.rbac_role_permissions
    WHERE role_id = _role_id AND permission_code = _code;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rbac_set_role_permission(uuid, text, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.rbac_bulk_set_permissions(_role_id uuid, _codes text[], _accorde boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_permission('roles_permissions.assigner_permission');
  IF COALESCE(array_length(_codes, 1), 0) = 0 THEN
    RETURN;
  END IF;
  IF _accorde THEN
    INSERT INTO public.rbac_role_permissions(role_id, permission_code, accorde)
    SELECT _role_id, unnest(_codes), true
    ON CONFLICT (role_id, permission_code) DO UPDATE SET accorde = true;
  ELSE
    DELETE FROM public.rbac_role_permissions
    WHERE role_id = _role_id AND permission_code = ANY(_codes);
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rbac_bulk_set_permissions(uuid, text[], boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_permission_denied(_perm text, _context jsonb DEFAULT '{}'::jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.rbac_audit_log(user_id, action, details)
  VALUES (auth.uid(), 'permission_denied', jsonb_build_object('permission', _perm, 'context', _context, 'source', 'client'));
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_permission_denied(text, jsonb) TO authenticated;

-- Keep legacy compatibility column synchronized when present
CREATE OR REPLACE FUNCTION public.trg_rbac_user_roles_sync_legacy()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.rbac_role_id IS NULL THEN
    NEW.rbac_role_id := NEW.role_id;
  END IF;
  IF NEW.role_id IS NULL THEN
    NEW.role_id := NEW.rbac_role_id;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_rbac_user_roles_sync_legacy ON public.rbac_user_roles;
CREATE TRIGGER trg_rbac_user_roles_sync_legacy
  BEFORE INSERT OR UPDATE ON public.rbac_user_roles
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_user_roles_sync_legacy();

-- Audit triggers for matrix and assignments
CREATE OR REPLACE FUNCTION public.trg_rbac_audit_rp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    VALUES (auth.uid(), v_email, OLD.role_id, v_code, 'perm_remove', jsonb_build_object('permission', OLD.permission_code));
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;
DROP TRIGGER IF EXISTS trg_rbac_rp_audit ON public.rbac_role_permissions;
CREATE TRIGGER trg_rbac_rp_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.rbac_role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_rp();

CREATE OR REPLACE FUNCTION public.trg_rbac_audit_ur()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_email text; v_code text; v_target uuid;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  v_target := COALESCE(NEW.user_id, OLD.user_id);
  SELECT code INTO v_code FROM public.rbac_roles WHERE role_id = COALESCE(NEW.role_id, OLD.role_id);
  INSERT INTO public.rbac_audit_log(user_id, user_email, role_id, role_code, action, details)
  VALUES (auth.uid(), v_email, COALESCE(NEW.role_id, OLD.role_id), v_code,
    CASE WHEN TG_OP = 'INSERT' THEN 'assign' ELSE 'unassign' END,
    jsonb_build_object('target_user_id', v_target));
  RETURN COALESCE(NEW, OLD);
END;
$$;
DROP TRIGGER IF EXISTS trg_rbac_ur_audit ON public.rbac_user_roles;
CREATE TRIGGER trg_rbac_ur_audit
  AFTER INSERT OR DELETE ON public.rbac_user_roles
  FOR EACH ROW EXECUTE FUNCTION public.trg_rbac_audit_ur();