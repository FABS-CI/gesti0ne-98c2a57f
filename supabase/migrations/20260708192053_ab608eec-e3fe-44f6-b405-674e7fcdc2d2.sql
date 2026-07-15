-- Lot 8a: Sécurité RLS/GRANT
-- 1) Fix search_path sur trigger paiements
ALTER FUNCTION public.trg_paiements_guard() SET search_path = public;

-- 2) Révoquer EXECUTE des rôles anonymes/PUBLIC sur les fonctions SECURITY DEFINER destructives / sensibles
--    (le rôle 'authenticated' garde l'accès pour l'app ; 'anon' et PUBLIC ne doivent pas pouvoir appeler)
DO $$
DECLARE
  fn_name text;
  fn_names text[] := ARRAY[
    'detect_security_alerts',
    'rejeter_paiement',
    'supprimer_achat',
    'supprimer_client',
    'supprimer_colisage',
    'supprimer_commande_definitif',
    'supprimer_employe',
    'supprimer_fournisseur',
    'supprimer_livraison_suivi',
    'supprimer_produit',
    'supprimer_tournee',
    'trg_paiements_enforce_validation',
    'valider_paiement'
  ];
BEGIN
  FOREACH fn_name IN ARRAY fn_names LOOP
    -- gérer toutes les signatures existantes de chaque fonction
    FOR fn_name IN
      SELECT n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = fn_name
    LOOP
      EXECUTE 'REVOKE EXECUTE ON FUNCTION ' || fn_name || ' FROM PUBLIC, anon';
    END LOOP;
  END LOOP;
END $$;

-- Note: get_carton_public conserve volontairement l'accès anon (endpoint public de suivi carton).
-- trg_paiements_enforce_validation est un trigger — le REVOKE ne casse pas les triggers (exécutés en tant que propriétaire).