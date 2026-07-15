
CREATE OR REPLACE FUNCTION public.executer_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE t record; l record;
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO t FROM public.transferts WHERE transfert_id = _transfert_id FOR UPDATE;
  IF t IS NULL THEN RAISE EXCEPTION 'Transfert introuvable'; END IF;
  IF t.statut <> 'brouillon' THEN RAISE EXCEPTION 'Transfert déjà traité (%)', t.statut; END IF;
  FOR l IN SELECT * FROM public.transfert_lignes WHERE transfert_id = _transfert_id LOOP
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
      VALUES (l.produit_id, 'transfert_sortie', l.quantite,
              'Transfert ' || t.numero, t.depot_source_id);
    INSERT INTO public.stock_mouvements (produit_id, type, quantite, motif, depot_id)
      VALUES (l.produit_id, 'transfert_entree', l.quantite,
              'Transfert ' || t.numero, t.depot_destination_id);
  END LOOP;
  UPDATE public.transferts
    SET statut = 'expedie', date_expedition = now()
    WHERE transfert_id = _transfert_id;
END $$;

CREATE OR REPLACE FUNCTION public.receptionner_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.transferts SET statut = 'recu', date_reception = now()
    WHERE transfert_id = _transfert_id AND statut = 'expedie';
  IF NOT FOUND THEN RAISE EXCEPTION 'Transfert introuvable ou non expédié'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.annuler_transfert(_transfert_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_any_role(auth.uid(),
       ARRAY['super_admin','directeur_general','gestionnaire_stock','responsable_magasinier']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.transferts SET statut = 'annule'
    WHERE transfert_id = _transfert_id AND statut = 'brouillon';
  IF NOT FOUND THEN RAISE EXCEPTION 'Transfert introuvable ou déjà traité'; END IF;
END $$;
