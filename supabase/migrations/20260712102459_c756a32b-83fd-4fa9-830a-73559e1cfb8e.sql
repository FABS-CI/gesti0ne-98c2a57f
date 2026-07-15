DO $$
DECLARE
  m text[][] := ARRAY[
    ['commandes','reference'],['proformas','reference'],['bons_livraison','reference'],
    ['livraisons','reference'],['factures','reference'],['fne_factures','reference'],
    ['avoirs','reference'],['bons_retour','reference'],['retours','reference'],
    ['achats','reference'],['paiements','reference'],['tournees','reference'],
    ['inventaires','reference'],['transferts','numero'],['incidents','reference'],
    ['specimens','reference'],['expeditions','reference'],['ordres_colisage','reference'],
    ['missions','reference']
  ];
  i int; tbl text; col text;
BEGIN
  FOR i IN 1..array_length(m,1) LOOP
    tbl := m[i][1]; col := m[i][2];
    -- Backfill au cas où (compat rows anciennes avec NULL)
    EXECUTE format(
      'UPDATE public.%I SET %I = public.next_document_number(%L, EXTRACT(year FROM COALESCE(created_at, now()))::int) WHERE %I IS NULL',
      tbl, col,
      CASE tbl
        WHEN 'commandes' THEN 'CMD' WHEN 'proformas' THEN 'PF'
        WHEN 'bons_livraison' THEN 'BL' WHEN 'livraisons' THEN 'LV'
        WHEN 'factures' THEN 'FA' WHEN 'fne_factures' THEN 'FN'
        WHEN 'avoirs' THEN 'AV' WHEN 'bons_retour' THEN 'BR'
        WHEN 'retours' THEN 'RET' WHEN 'achats' THEN 'ACH'
        WHEN 'paiements' THEN 'PMT' WHEN 'tournees' THEN 'TRN'
        WHEN 'inventaires' THEN 'INV' WHEN 'transferts' THEN 'TR'
        WHEN 'incidents' THEN 'INC' WHEN 'specimens' THEN 'SPE'
        WHEN 'expeditions' THEN 'EXP' WHEN 'ordres_colisage' THEN 'OC'
        WHEN 'missions' THEN 'MIS'
      END,
      col
    );
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I SET NOT NULL', tbl, col);
  END LOOP;
END$$;
