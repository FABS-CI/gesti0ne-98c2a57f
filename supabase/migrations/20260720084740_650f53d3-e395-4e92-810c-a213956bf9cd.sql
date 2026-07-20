
-- 1) Migration des données : si telephone est vide et telephone2 renseigné, on transfère
UPDATE public.clients
   SET telephone = telephone2
 WHERE (telephone IS NULL OR btrim(telephone) = '')
   AND telephone2 IS NOT NULL
   AND btrim(telephone2) <> '';

-- 2) Suppression définitive des colonnes
ALTER TABLE public.clients DROP COLUMN IF EXISTS telephone2;
ALTER TABLE public.clients DROP COLUMN IF EXISTS contact_principal;
