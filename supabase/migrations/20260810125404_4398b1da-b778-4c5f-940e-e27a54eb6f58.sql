ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS password_compromised_at timestamptz;

COMMENT ON COLUMN public.profiles.must_change_password IS
  'Force la définition d''un nouveau mot de passe à la prochaine connexion (rotation de secret compromis).';

UPDATE public.profiles p
SET must_change_password = true,
    password_compromised_at = now(),
    updated_at = now()
WHERE lower(p.email) IN (
  SELECT lower(u.email) FROM auth.users u
  WHERE lower(u.email) LIKE '%@editionsfabsci.com'
);
