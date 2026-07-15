
-- Fonction : renvoie l'exercice actif
CREATE OR REPLACE FUNCTION public.exercice_actif_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT exercice_id FROM public.exercices WHERE is_actif LIMIT 1;
$$;

-- Ajout d'un DEFAULT sur toutes les colonnes exercice_id
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT unnest(ARRAY[
      'commandes','proformas','factures','bons_livraison','bons_retour','retours',
      'achats','paiements','transactions','stock_mouvements','inventaires',
      'bulletins_paie','ecritures_comptables'
    ]) AS tbl
  LOOP
    EXECUTE format(
      'ALTER TABLE public.%I ALTER COLUMN exercice_id SET DEFAULT public.exercice_actif_id()',
      r.tbl
    );
  END LOOP;
END $$;
