
-- =========================================================================
-- AUDIT SÉCURITÉ P0 : verrouillage des privilèges EXECUTE
-- Contexte : le scanner remonte 101 warnings SECURITY DEFINER.
-- Analyse : la plupart sont légitimes (helpers RLS has_role/has_permission_v2
-- doivent rester callable authenticated), MAIS deux RPCs de mutation sont
-- exposés à ANON (creer_colisage_manuel, modifier_colis_lignes) et toutes
-- les trigger functions ont EXECUTE à public par défaut.
-- =========================================================================

-- 1) FIX CRITIQUE : révoquer ANON sur les RPCs de mutation exposés par erreur
REVOKE EXECUTE ON FUNCTION public.creer_colisage_manuel(uuid, jsonb, jsonb) FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.creer_colisage_manuel(uuid, jsonb, jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.modifier_colis_lignes(uuid, jsonb, text) FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.modifier_colis_lignes(uuid, jsonb, text) TO authenticated;

-- 2) Trigger functions et helpers d'énumération : REVOKE FROM public/anon
-- (retour trigger => non appelable via PostgREST, mais on nettoie le bruit)
REVOKE EXECUTE ON FUNCTION public.audit_colisage_responsables()             FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.guard_colis_historique_immutable()        FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.guard_commande_delete()                   FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.livsuivi_guard_historique()               FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.set_updated_at()                          FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.sync_doc_montant_from_commande()          FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.tournees_set_updated_at()                 FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.bootstrap_first_super_admin()             FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()                         FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.apply_stock_mouvement()                   FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.autocreate_proforma_for_commande()        FROM anon, public;

-- 3) Helpers publics non-sensibles : garder authenticated
REVOKE EXECUTE ON FUNCTION public.livsuivi_next_etape(livsuivi_type, livsuivi_statut) FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.livsuivi_next_etape(livsuivi_type, livsuivi_statut) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.valider_transition_livraison(statut_livraison_cmd, statut_livraison_cmd, type_livraison) FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.valider_transition_livraison(statut_livraison_cmd, statut_livraison_cmd, type_livraison) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.produit_niveau_ordre(text) FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.produit_niveau_ordre(text) TO authenticated;

-- 4) Seule fonction légitime ANON : QR code carton public (déjà accordée)
-- vérification : GRANT EXECUTE ON FUNCTION public.get_carton_public(uuid) TO anon; (idempotent)
GRANT EXECUTE ON FUNCTION public.get_carton_public(uuid) TO anon;

-- 5) Blindage : révoquer EXECUTE par défaut sur toutes les futures fonctions de public
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM public;
