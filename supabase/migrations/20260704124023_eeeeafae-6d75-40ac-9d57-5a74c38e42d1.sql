
SET session_replication_role = replica;

WITH ids(id) AS (VALUES ('16c93705-f606-440d-9acd-d6a6bf396dc8'::uuid),('d2039add-6e5d-4d11-bac3-9359023b36f6'::uuid))
, del_cl AS (DELETE FROM commande_lignes WHERE commande_id IN (SELECT commande_id FROM commandes WHERE exercice_id IN (SELECT id FROM ids)) RETURNING 1)
, del_c  AS (DELETE FROM commandes WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_pl AS (DELETE FROM proforma_lignes WHERE proforma_id IN (SELECT proforma_id FROM proformas WHERE exercice_id IN (SELECT id FROM ids)) RETURNING 1)
, del_p  AS (DELETE FROM proformas WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_f  AS (DELETE FROM factures WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_bl AS (DELETE FROM bons_livraison WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_br AS (DELETE FROM bons_retour WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_rl AS (DELETE FROM retour_lignes WHERE retour_id IN (SELECT retour_id FROM retours WHERE exercice_id IN (SELECT id FROM ids)) RETURNING 1)
, del_r  AS (DELETE FROM retours WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_al AS (DELETE FROM achat_lignes WHERE achat_id IN (SELECT achat_id FROM achats WHERE exercice_id IN (SELECT id FROM ids)) RETURNING 1)
, del_a  AS (DELETE FROM achats WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_pa AS (DELETE FROM paiements WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_tx AS (DELETE FROM transactions WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_sm AS (DELETE FROM stock_mouvements WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_il AS (DELETE FROM inventaire_lignes WHERE inventaire_id IN (SELECT inventaire_id FROM inventaires WHERE exercice_id IN (SELECT id FROM ids)) RETURNING 1)
, del_i  AS (DELETE FROM inventaires WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_bp AS (DELETE FROM bulletins_paie WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_el AS (DELETE FROM ecriture_lignes WHERE ecriture_id IN (SELECT ecriture_id FROM ecritures_comptables WHERE exercice_id IN (SELECT id FROM ids)) RETURNING 1)
, del_e  AS (DELETE FROM ecritures_comptables WHERE exercice_id IN (SELECT id FROM ids) RETURNING 1)
, del_sc AS (DELETE FROM soldes_ouverture_clients WHERE exercice_id IN (SELECT id FROM ids) OR exercice_origine_id IN (SELECT id FROM ids) RETURNING 1)
, del_sf AS (DELETE FROM soldes_ouverture_fournisseurs WHERE exercice_id IN (SELECT id FROM ids) OR exercice_origine_id IN (SELECT id FROM ids) RETURNING 1)
, del_cj AS (DELETE FROM exercice_cloture_journal WHERE exercice_source_id IN (SELECT id FROM ids) OR exercice_cible_id IN (SELECT id FROM ids) RETURNING 1)
DELETE FROM exercices WHERE exercice_id IN (SELECT id FROM ids);

SET session_replication_role = DEFAULT;
