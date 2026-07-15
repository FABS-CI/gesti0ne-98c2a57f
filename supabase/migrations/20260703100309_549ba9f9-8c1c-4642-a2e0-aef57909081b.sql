-- Activer Realtime pour les tables RBAC afin que les modifications de la matrice
-- se propagent immédiatement aux sessions utilisateurs (invalidation du cache
-- de permissions dans use-permissions.ts).
ALTER TABLE public.rbac_role_permissions REPLICA IDENTITY FULL;
ALTER TABLE public.rbac_user_roles REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='rbac_role_permissions'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.rbac_role_permissions';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='rbac_user_roles'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.rbac_user_roles';
  END IF;
END $$;