
ALTER TABLE public.stock_mouvements DISABLE TRIGGER trg_stock_mouvements_no_delete;

DELETE FROM public.stock_mouvements
 WHERE produit_id IN (SELECT produit_id FROM public.produits WHERE reference NOT LIKE 'FABS-CI%');

ALTER TABLE public.stock_mouvements ENABLE TRIGGER trg_stock_mouvements_no_delete;

DELETE FROM public.stocks_depots
 WHERE produit_id IN (SELECT produit_id FROM public.produits WHERE reference NOT LIKE 'FABS-CI%');

DELETE FROM public.produits WHERE reference NOT LIKE 'FABS-CI%';

DELETE FROM public.clients
 WHERE nom LIKE 'TEST%' OR nom LIKE 'E2E%' OR reference LIKE 'TEST%' OR reference LIKE 'E2E%';
