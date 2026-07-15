-- Trigger-only functions: revoke EXECUTE from PUBLIC / anon / authenticated.
-- They are invoked by the trigger system with owner privileges; no client needs to call them.
DO $$
DECLARE
  fn text;
  trigger_fns text[] := ARRAY[
    'apply_stock_mouvement()',
    'audit_colisage_responsables()',
    'autocreate_proforma_for_commande()',
    'bootstrap_first_super_admin()',
    'handle_new_user()',
    'livsuivi_from_bl()',
    'livsuivi_notify_client()',
    'notifier_changement_statut_livraison()',
    'set_specimen_reference()',
    'sync_doc_montant_from_commande()',
    'sync_proforma_from_commande()',
    'sync_proforma_lignes_from_commande()',
    'trg_alerte_seuil_principal()',
    'trg_audit_generic()',
    'trg_colis_sync_livraison_cmd()',
    'trg_depots_principal_unique()',
    'trg_notif_absences()',
    'trg_notif_achats()',
    'trg_notif_bl()',
    'trg_notif_commandes()',
    'trg_notif_conges()',
    'trg_notif_factures()',
    'trg_notif_livraisons()',
    'trg_notif_paiements()',
    'trg_notif_stock()',
    'trg_notif_tournees()',
    'trg_notif_user_roles()',
    'trg_rbac_audit_rp()',
    'trg_rbac_audit_ur()',
    'trg_specimen_lignes_totaux()',
    'trg_stocks_depots_refresh()'
  ];
BEGIN
  FOREACH fn IN ARRAY trigger_fns LOOP
    BEGIN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', fn);
    EXCEPTION WHEN undefined_function THEN
      RAISE NOTICE 'skip %', fn;
    END;
  END LOOP;
END $$;