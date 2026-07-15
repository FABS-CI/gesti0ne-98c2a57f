
-- Point 3: analytique — permettre de tracer les lignes comptables par tournée
ALTER TABLE public.ecriture_lignes
  ADD COLUMN IF NOT EXISTS tournee_id uuid REFERENCES public.tournees(tournee_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_ecriture_lignes_tournee ON public.ecriture_lignes(tournee_id) WHERE tournee_id IS NOT NULL;

-- Recompiler la RPC pour renseigner tournee_id sur toutes les lignes
CREATE OR REPLACE FUNCTION public.valider_decaissement_tournee(_tournee_id uuid, _mode_reglement text, _commentaire text DEFAULT NULL::text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_t public.tournees;
  v_exercice_id uuid;
  v_journal text;
  v_compte_tresorerie text;
  v_libelle_tresorerie text;
  v_ecriture_id uuid;
  v_ref text;
BEGIN
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin','directeur_general','comptable']::app_role[]) THEN
    RAISE EXCEPTION 'Accès refusé : seule la comptabilité peut valider un décaissement.';
  END IF;
  IF _mode_reglement NOT IN ('caisse','banque') THEN
    RAISE EXCEPTION 'Mode de règlement invalide (caisse ou banque attendu).';
  END IF;

  SELECT * INTO v_t FROM public.tournees WHERE tournee_id = _tournee_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tournée introuvable.'; END IF;
  IF v_t.validation_statut = 'decaisse' THEN
    RAISE EXCEPTION 'Cette tournée est déjà décaissée.';
  END IF;
  IF COALESCE(v_t.cout_total,0) <= 0 THEN
    RAISE EXCEPTION 'Aucun coût à valider pour cette tournée.';
  END IF;

  IF _mode_reglement = 'caisse' THEN
    v_journal := 'CA'; v_compte_tresorerie := '571'; v_libelle_tresorerie := 'Caisse';
  ELSE
    v_journal := 'BQ'; v_compte_tresorerie := '521'; v_libelle_tresorerie := 'Banque';
  END IF;

  SELECT exercice_id INTO v_exercice_id
  FROM public.exercices
  WHERE v_t.date_tournee BETWEEN date_debut AND date_fin
  ORDER BY date_debut DESC LIMIT 1;
  IF v_exercice_id IS NULL THEN
    SELECT exercice_id INTO v_exercice_id FROM public.exercices
    WHERE statut = 'actif' ORDER BY date_debut DESC LIMIT 1;
  END IF;
  IF v_exercice_id IS NULL THEN
    RAISE EXCEPTION 'Aucun exercice comptable ouvert pour la date de la tournée.';
  END IF;

  v_ref := 'DEC-' || v_t.reference;

  INSERT INTO public.ecritures_comptables (
    reference, date_ecriture, journal, libelle,
    source_type, source_id, montant_total, exercice_id
  ) VALUES (
    v_ref, v_t.date_tournee, v_journal,
    'Décaissement tournée ' || v_t.reference,
    'tournee', v_t.tournee_id, v_t.cout_total, v_exercice_id
  ) RETURNING ecriture_id INTO v_ecriture_id;

  IF COALESCE(v_t.cout_carburant,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6241', 'Carburant', v_t.cout_carburant, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_peages,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6242', 'Péages', v_t.cout_peages, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_repas,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6256', 'Repas / Missions', v_t.cout_repas, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_manutentions,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6244', 'Manutention', v_t.cout_manutentions, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_expeditions,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6245', 'Expéditions / Transport', v_t.cout_expeditions, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_livraison,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6246', 'Frais de livraison', v_t.cout_livraison, 0, v_t.tournee_id);
  END IF;
  IF COALESCE(v_t.cout_autres,0) > 0 THEN
    INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
    VALUES (v_ecriture_id, '6288', 'Autres frais logistiques', v_t.cout_autres, 0, v_t.tournee_id);
  END IF;

  INSERT INTO public.ecriture_lignes(ecriture_id, compte, compte_libelle, debit, credit, tournee_id)
  VALUES (v_ecriture_id, v_compte_tresorerie, v_libelle_tresorerie, 0, v_t.cout_total, v_t.tournee_id);

  UPDATE public.tournees SET
    validation_statut = 'decaisse',
    validation_at = now(),
    validation_by = auth.uid(),
    validation_commentaire = COALESCE(_commentaire, validation_commentaire),
    mode_reglement = _mode_reglement,
    ecriture_id = v_ecriture_id,
    updated_at = now(),
    updated_by = auth.uid()
  WHERE tournee_id = _tournee_id;

  INSERT INTO public.couts_logistiques_audit(tournee_id, action, ancien_statut, nouveau_statut, commentaire, user_id)
  VALUES (_tournee_id, 'decaissement', v_t.validation_statut, 'decaisse',
          'Écriture ' || v_ref || ' générée (' || v_journal || ')', auth.uid());

  RETURN v_ecriture_id;
END;
$function$;

-- Point 1: propagation des statuts Tournée -> Colis + livraisons_commande
CREATE OR REPLACE FUNCTION public.propagate_tournee_statut()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.statut IS DISTINCT FROM OLD.statut THEN
    IF NEW.statut = 'en_cours' THEN
      UPDATE public.colis
         SET statut_logistique = 'en_transit',
             statut = CASE WHEN statut IN ('en_preparation','prete') THEN 'expedie' ELSE statut END,
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut_logistique NOT IN ('livre','retour');
      UPDATE public.livraisons_commande
         SET statut = 'en_livraison'::statut_livraison_cmd,
             heure_depart = COALESCE(heure_depart, now()),
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut NOT IN ('livree'::statut_livraison_cmd, 'annulee'::statut_livraison_cmd);
    ELSIF NEW.statut = 'cloturee' THEN
      UPDATE public.colis
         SET statut_logistique = 'livre',
             statut = 'livre',
             date_livraison_reelle = COALESCE(date_livraison_reelle, now()),
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut_logistique NOT IN ('livre','retour');
      UPDATE public.livraisons_commande
         SET statut = 'livree'::statut_livraison_cmd,
             date_livraison = COALESCE(date_livraison, now()),
             progression_pct = 100,
             updated_at = now()
       WHERE tournee_id = NEW.tournee_id
         AND statut NOT IN ('livree'::statut_livraison_cmd, 'annulee'::statut_livraison_cmd);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_propagate_tournee_statut ON public.tournees;
CREATE TRIGGER trg_propagate_tournee_statut
  AFTER UPDATE OF statut ON public.tournees
  FOR EACH ROW EXECUTE FUNCTION public.propagate_tournee_statut();

-- Point 2: propagation livreur / véhicule Tournée -> Colis + livraisons_commande
CREATE OR REPLACE FUNCTION public.propagate_tournee_ressources()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_livreur_nom text;
  v_livreur_tel text;
  v_vehicule_txt text;
BEGIN
  IF NEW.livreur_id IS DISTINCT FROM OLD.livreur_id THEN
    SELECT nom, telephone INTO v_livreur_nom, v_livreur_tel
      FROM public.livreurs WHERE livreur_id = NEW.livreur_id;
    UPDATE public.livraisons_commande
       SET livreur_id = NEW.livreur_id, updated_at = now()
     WHERE tournee_id = NEW.tournee_id;
    UPDATE public.colis
       SET livreur_nom = COALESCE(v_livreur_nom, livreur_nom),
           livreur_telephone = COALESCE(v_livreur_tel, livreur_telephone),
           updated_at = now()
     WHERE tournee_id = NEW.tournee_id;
  END IF;

  IF NEW.vehicule_id IS DISTINCT FROM OLD.vehicule_id THEN
    SELECT COALESCE(immatriculation, marque || ' ' || modele) INTO v_vehicule_txt
      FROM public.vehicules WHERE vehicule_id = NEW.vehicule_id;
    UPDATE public.colis
       SET vehicule = COALESCE(v_vehicule_txt, vehicule),
           updated_at = now()
     WHERE tournee_id = NEW.tournee_id;
    UPDATE public.livraisons_commande
       SET vehicule = COALESCE(v_vehicule_txt, vehicule),
           updated_at = now()
     WHERE tournee_id = NEW.tournee_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_propagate_tournee_ressources ON public.tournees;
CREATE TRIGGER trg_propagate_tournee_ressources
  AFTER UPDATE OF livreur_id, vehicule_id ON public.tournees
  FOR EACH ROW EXECUTE FUNCTION public.propagate_tournee_ressources();
