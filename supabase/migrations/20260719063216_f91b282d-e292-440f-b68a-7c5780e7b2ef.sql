ALTER TABLE public.bons_livraison DROP CONSTRAINT IF EXISTS bons_livraison_statut_check;
ALTER TABLE public.bons_livraison ADD CONSTRAINT bons_livraison_statut_check
  CHECK (statut = ANY (ARRAY[
    'brouillon'::text,
    'a_preparer'::text,
    'en_preparation'::text,
    'colisage_en_cours'::text,
    'colisage_termine'::text,
    'pret'::text,
    'expedie'::text,
    'livre'::text,
    'annule'::text,
    'annulee'::text
  ]));