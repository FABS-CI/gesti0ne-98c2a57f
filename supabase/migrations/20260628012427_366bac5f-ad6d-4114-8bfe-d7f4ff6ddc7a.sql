-- 1. Helper: utilisateur appartenant au personnel (au moins une fonction attribuée)
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id) $$;

-- 2. Helper: utilisateur ayant au moins l'un des rôles donnés
CREATE OR REPLACE FUNCTION public.has_any_role(_user_id uuid, _roles public.app_role[])
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = ANY(_roles)) $$;

-- 3. Convertir toutes les politiques "true" (sauf profiles/user_roles) en exigence "personnel"
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename NOT IN ('profiles', 'user_roles')
  LOOP
    IF p.qual = 'true' THEN
      EXECUTE format('ALTER POLICY %I ON public.%I USING (public.is_staff(auth.uid()))', p.policyname, p.tablename);
    END IF;
    IF p.with_check = 'true' THEN
      EXECUTE format('ALTER POLICY %I ON public.%I WITH CHECK (public.is_staff(auth.uid()))', p.policyname, p.tablename);
    END IF;
  END LOOP;
END $$;

-- 4. Restreindre les données FINANCIÈRES
DO $$
DECLARE p record;
  expr text := 'public.has_any_role(auth.uid(), ARRAY[''super_admin'',''directeur_general'',''comptable'']::public.app_role[])';
BEGIN
  FOR p IN
    SELECT tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('transactions', 'factures', 'paiements', 'bulletins_paie')
  LOOP
    IF p.qual IS NOT NULL THEN
      EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)', p.policyname, p.tablename, expr);
    END IF;
    IF p.with_check IS NOT NULL THEN
      EXECUTE format('ALTER POLICY %I ON public.%I WITH CHECK (%s)', p.policyname, p.tablename, expr);
    END IF;
  END LOOP;
END $$;

-- 5. Restreindre les données RH
DO $$
DECLARE p record;
  expr text := 'public.has_any_role(auth.uid(), ARRAY[''super_admin'',''directeur_general'',''secretariat'']::public.app_role[])';
BEGIN
  FOR p IN
    SELECT tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('employes', 'contrats', 'conges', 'absences', 'evaluations')
  LOOP
    IF p.qual IS NOT NULL THEN
      EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)', p.policyname, p.tablename, expr);
    END IF;
    IF p.with_check IS NOT NULL THEN
      EXECUTE format('ALTER POLICY %I ON public.%I WITH CHECK (%s)', p.policyname, p.tablename, expr);
    END IF;
  END LOOP;
END $$;

-- 6. Gestion des rôles réservée au super_admin
DROP POLICY IF EXISTS "Super admin manage roles" ON public.user_roles;
CREATE POLICY "Super admin manage roles" ON public.user_roles
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'))
  WITH CHECK (public.has_role(auth.uid(), 'super_admin'));
