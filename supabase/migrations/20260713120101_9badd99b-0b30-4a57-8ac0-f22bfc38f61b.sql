CREATE OR REPLACE FUNCTION public.trg_guard_profiles_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF OLD.is_restricted IS DISTINCT FROM NEW.is_restricted
     OR OLD.mfa_required IS DISTINCT FROM NEW.mfa_required
     OR OLD.mfa_enrolled_at IS DISTINCT FROM NEW.mfa_enrolled_at THEN
    IF COALESCE(auth.role(), '') = 'service_role'
       OR current_user IN ('postgres', 'service_role')
       OR public.has_any_role(auth.uid(), ARRAY['super_admin'::public.app_role, 'directeur_general'::public.app_role]) THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Modification interdite des champs sensibles du profil'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profiles_sensitive_fields ON public.profiles;
CREATE TRIGGER trg_guard_profiles_sensitive_fields
  BEFORE UPDATE OF is_restricted, mfa_required, mfa_enrolled_at ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_guard_profiles_sensitive_fields();