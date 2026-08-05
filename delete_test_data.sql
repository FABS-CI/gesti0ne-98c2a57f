-- Delete invoices specifically mentioned or matching patterns
DELETE FROM public.factures 
WHERE reference = 'FAC-2026-00003' 
   OR reference = 'FAC-2026-00001'
   OR reference LIKE 'FAC-2026-%';

-- Delete clients with TEST-INT- prefix
-- Note: This might fail if there are dependent records in other tables
-- (like factures, proformas, etc.) not deleted above.
-- We use a recursive approach or specific order if we know them.

-- First, delete all related documents for these clients to avoid foreign key violations
DELETE FROM public.factures WHERE client_id IN (SELECT id FROM public.clients WHERE nom LIKE '%TEST-INT-%');
DELETE FROM public.proformas WHERE client_id IN (SELECT id FROM public.clients WHERE nom LIKE '%TEST-INT-%');
DELETE FROM public.bons_commande WHERE client_id IN (SELECT id FROM public.clients WHERE nom LIKE '%TEST-INT-%');
DELETE FROM public.bons_livraison WHERE client_id IN (SELECT id FROM public.clients WHERE nom LIKE '%TEST-INT-%');
DELETE FROM public.retours_clients WHERE client_id IN (SELECT id FROM public.clients WHERE nom LIKE '%TEST-INT-%');
DELETE FROM public.paiements WHERE client_id IN (SELECT id FROM public.clients WHERE nom LIKE '%TEST-INT-%');

-- Now delete the clients
DELETE FROM public.clients WHERE nom LIKE '%TEST-INT-%';
