-- Correction du bug: livsuivi_historique.livraison_id (et non livsuivi_id)
CREATE OR REPLACE FUNCTION public.supprimer_commande_definitif(_commande_id uuid, _motif text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    _is_super_admin boolean;
    _liv_ids uuid[];
    _colis_ids uuid[];
    _bl_ids uuid[];
    _facture_ids uuid[];
    _proforma_ids uuid[];
    _ref text;
    _dates date[];
    _d date;
    _mv record;
BEGIN
    SELECT public.has_role(auth.uid(), 'super_admin'::app_role) INTO _is_super_admin;
    IF NOT _is_super_admin THEN
        RAISE EXCEPTION 'Accès refusé : super_admin uniquement';
    END IF;

    PERFORM set_config('app.allow_paiement_delete', 'on', true);

    SELECT reference INTO _ref FROM public.commandes WHERE commande_id = _commande_id;
    IF _ref IS NULL THEN
      RAISE EXCEPTION 'Commande introuvable';
    END IF;

    SELECT array_agg(livraison_id) INTO _liv_ids FROM public.livraisons_commande WHERE commande_id = _commande_id;
    SELECT array_agg(colis_id)     INTO _colis_ids FROM public.colis WHERE commande_id = _commande_id;
    SELECT array_agg(bl_id)        INTO _bl_ids FROM public.bons_livraison WHERE commande_id = _commande_id;
    SELECT array_agg(facture_id)   INTO _facture_ids FROM public.factures WHERE commande_id = _commande_id;
    SELECT array_agg(proforma_id)  INTO _proforma_ids FROM public.proformas WHERE commande_id = _commande_id;

    IF _colis_ids IS NOT NULL THEN
      SELECT array_agg(DISTINCT date_colisage::date)
        INTO _dates
      FROM public.colis WHERE colis_id = ANY(_colis_ids);
    END IF;

    IF _colis_ids IS NOT NULL OR _bl_ids IS NOT NULL OR _facture_ids IS NOT NULL THEN
      FOR _mv IN
        SELECT * FROM public.stock_mouvements
        WHERE (document_table = 'colis'          AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
           OR (document_table = 'bons_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
           OR (document_table = 'factures'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
           OR (document_table = 'commandes'      AND document_id = _commande_id)
      LOOP
        IF _mv.depot_id IS NOT NULL AND _mv.produit_id IS NOT NULL THEN
          UPDATE public.stocks_depots
             SET quantite = GREATEST(0, quantite + COALESCE(_mv.quantite_sortie,0) - COALESCE(_mv.quantite_entree,0)),
                 updated_at = now()
           WHERE produit_id = _mv.produit_id AND depot_id = _mv.depot_id;
        END IF;
      END LOOP;

      DELETE FROM public.stock_mouvements
      WHERE (document_table = 'colis'          AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
         OR (document_table = 'bons_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
         OR (document_table = 'factures'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
         OR (document_table = 'commandes'      AND document_id = _commande_id);
    END IF;

    IF _facture_ids IS NOT NULL THEN
      DELETE FROM public.retour_lignes rl USING public.retours r
        WHERE rl.retour_id = r.retour_id AND r.facture_id = ANY(_facture_ids);
      DELETE FROM public.retours WHERE facture_id = ANY(_facture_ids);
      DELETE FROM public.bons_retour WHERE facture_id = ANY(_facture_ids);
      DELETE FROM public.fne_factures WHERE facture_id = ANY(_facture_ids);
    END IF;
    DELETE FROM public.retour_lignes rl USING public.retours r
      WHERE rl.retour_id = r.retour_id AND r.commande_id = _commande_id;
    DELETE FROM public.retours WHERE commande_id = _commande_id;

    -- FIX: livsuivi_historique.livraison_id (au lieu de livsuivi_id)
    DELETE FROM public.livsuivi_historique lh
      USING public.livsuivi_commandes lc
      WHERE lh.livraison_id = lc.id AND lc.commande_id = _commande_id;
    DELETE FROM public.livsuivi_commandes WHERE commande_id = _commande_id;

    DELETE FROM public.notifications
     WHERE (document_type = 'commande'      AND document_id = _commande_id)
        OR (document_type = 'facture'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
        OR (document_type = 'bon_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
        OR (document_type = 'colis'         AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
        OR (document_type = 'proforma'      AND document_id = ANY(COALESCE(_proforma_ids,'{}'::uuid[])));

    DELETE FROM public.historique_envois
     WHERE (document_type = 'commande'      AND document_id = _commande_id)
        OR (document_type = 'facture'       AND document_id = ANY(COALESCE(_facture_ids,'{}'::uuid[])))
        OR (document_type = 'bon_livraison' AND document_id = ANY(COALESCE(_bl_ids,    '{}'::uuid[])))
        OR (document_type = 'colis'         AND document_id = ANY(COALESCE(_colis_ids, '{}'::uuid[])))
        OR (document_type = 'proforma'      AND document_id = ANY(COALESCE(_proforma_ids,'{}'::uuid[])));

    IF _liv_ids IS NOT NULL THEN
        DELETE FROM public.livraison_commande_historique WHERE livraison_id = ANY(_liv_ids);
        DELETE FROM public.livraisons_commande WHERE livraison_id = ANY(_liv_ids);
    END IF;
    IF _colis_ids IS NOT NULL THEN
        DELETE FROM public.colis_statut_historique WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colis_lignes WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colisage_modifications_historique WHERE colis_id = ANY(_colis_ids);
        DELETE FROM public.colis WHERE colis_id = ANY(_colis_ids);
    END IF;
    IF _bl_ids IS NOT NULL THEN
        DELETE FROM public.bons_livraison WHERE bl_id = ANY(_bl_ids);
    END IF;
    IF _facture_ids IS NOT NULL THEN
        DELETE FROM public.paiements WHERE facture_id = ANY(_facture_ids);
        DELETE FROM public.factures WHERE facture_id = ANY(_facture_ids);
    END IF;
    IF _proforma_ids IS NOT NULL THEN
        DELETE FROM public.proforma_lignes WHERE proforma_id = ANY(_proforma_ids);
        DELETE FROM public.proformas WHERE proforma_id = ANY(_proforma_ids);
    END IF;

    DELETE FROM public.commande_lignes WHERE commande_id = _commande_id;
    DELETE FROM public.commandes WHERE commande_id = _commande_id;

    IF _dates IS NOT NULL THEN
      FOREACH _d IN ARRAY _dates LOOP
        PERFORM public.recalc_tournee_from_colis(_d);
      END LOOP;
    END IF;

    INSERT INTO public.audit_events(action, module, table_name, record_id, record_ref, user_id, metadata, criticite)
    VALUES ('DELETE'::audit_action, 'commandes', 'commandes', _commande_id::text, _ref, auth.uid(),
            jsonb_build_object(
              'motif', _motif,
              'type', 'suppression_definitive',
              'colis_supprimes', COALESCE(array_length(_colis_ids,1),0),
              'bl_supprimes',    COALESCE(array_length(_bl_ids,1),0),
              'factures_supprimees', COALESCE(array_length(_facture_ids,1),0),
              'proformas_supprimees', COALESCE(array_length(_proforma_ids,1),0),
              'tournees_recalculees', COALESCE(array_length(_dates,1),0)
            ),
            'critical'::audit_criticite);
END;
$function$;

-- Nettoyage des 4 commandes E2E
DO $$
DECLARE
  cmd_id uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '2c55b97c-9cb8-47c1-b7a3-2f9b74114e26', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"2c55b97c-9cb8-47c1-b7a3-2f9b74114e26","role":"authenticated"}', true);
  PERFORM set_config('app.allow_stock_mouvement_delete', 'on', true);
  FOR cmd_id IN
    SELECT commande_id FROM public.commandes
    WHERE numero IN (
      'CMD-20260708-211109',
      'CMD-20260708-211124',
      'CMD-20260708-211150',
      'CMD-20260708-211311'
    )
  LOOP
    PERFORM public.supprimer_commande_definitif(cmd_id, 'Nettoyage E2E workflow-aller-retour');
  END LOOP;
END $$;