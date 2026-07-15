
ALTER TABLE public.vehicules
  ADD COLUMN IF NOT EXISTS date_prochain_entretien DATE,
  ADD COLUMN IF NOT EXISTS date_expiration_assurance DATE,
  ADD COLUMN IF NOT EXISTS date_expiration_visite_technique DATE;
