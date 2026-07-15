CREATE OR REPLACE FUNCTION public.profiles_block_sensitive_self_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  is_admin boolean;
BEGIN
  -- service_role (edge functions / admin) bypass complet
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Admins autorisés à modifier ces champs
  is_admin := public.has_any_role(auth.uid(), ARRAY['super_admin'::app_role, 'directeur_general'::app_role]);

  IF NOT is_admin THEN
    -- Force la conservation des valeurs sensibles (anti privilege escalation)
    NEW.is_restricted   := OLD.is_restricted;
    NEW.mfa_required    := OLD.mfa_required;
    NEW.mfa_enrolled_at := OLD.mfa_enrolled_at;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_block_sensitive_self_update ON public.profiles;
CREATE TRIGGER trg_profiles_block_sensitive_self_update
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.profiles_block_sensitive_self_update();

COMMENT ON FUNCTION public.profiles_block_sensitive_self_update() IS
'Correctif B-1 audit prod : empêche un utilisateur de s''auto-attribuer is_restricted=false, mfa_required=false ou mfa_enrolled_at via UPDATE de son propre profil. Seuls super_admin / directeur_general (et service_role) peuvent modifier ces colonnes.';