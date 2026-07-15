-- Attribution automatique du rôle 'commercial' à KASSI dès qu'il crée son compte
CREATE OR REPLACE FUNCTION public.grant_kassi_commercial_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL
     AND lower(NEW.email) = 'claverie@editionsfabsci.com' THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'commercial')
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_grant_kassi ON auth.users;
CREATE TRIGGER on_auth_user_created_grant_kassi
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.grant_kassi_commercial_role();

DROP TRIGGER IF EXISTS on_auth_user_confirmed_grant_kassi ON auth.users;
CREATE TRIGGER on_auth_user_confirmed_grant_kassi
AFTER UPDATE OF email_confirmed_at ON auth.users
FOR EACH ROW
WHEN (OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL)
EXECUTE FUNCTION public.grant_kassi_commercial_role();