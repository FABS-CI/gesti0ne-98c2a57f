DO $$
DECLARE
  m text[][] := ARRAY[
    ['commandes','reference','CMD'],['proformas','reference','PF'],
    ['bons_livraison','reference','BL'],['livraisons','reference','LV'],
    ['factures','reference','FA'],['fne_factures','reference','FN'],
    ['avoirs','reference','AV'],['bons_retour','reference','BR'],
    ['retours','reference','RET'],['achats','reference','ACH'],
    ['paiements','reference','PMT'],['tournees','reference','TRN'],
    ['inventaires','reference','INV'],['transferts','numero','TR'],
    ['incidents','reference','INC'],['specimens','reference','SPE'],
    ['expeditions','reference','EXP'],['ordres_colisage','reference','OC'],
    ['missions','reference','MIS']
  ];
  i int; tbl text; col text; prefix text;
BEGIN
  FOR i IN 1..array_length(m,1) LOOP
    tbl := m[i][1]; col := m[i][2]; prefix := m[i][3];
    EXECUTE format(
      'ALTER TABLE public.%I ALTER COLUMN %I SET DEFAULT public.next_document_number(%L)',
      tbl, col, prefix);
  END LOOP;
END$$;
