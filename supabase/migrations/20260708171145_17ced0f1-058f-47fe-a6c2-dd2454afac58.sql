-- RBAC : libellés FR + attribution par défaut
UPDATE public.rbac_permissions SET libelle = 'Peut valider les commandes'
  WHERE code = 'commandes.valider';
UPDATE public.rbac_permissions SET libelle = 'Peut valider les paiements'
  WHERE code = 'paiements.valider';

INSERT INTO public.rbac_role_permissions (role_id, permission_code, accorde)
SELECT r.role_id, p.code, true
  FROM public.rbac_roles r
  CROSS JOIN public.rbac_permissions p
 WHERE r.code IN ('super_admin','directeur_general','comptable')
   AND p.code IN ('commandes.valider','paiements.valider')
ON CONFLICT (role_id, permission_code) DO UPDATE SET accorde = true;

-- creer_commande : auto-validation si permission
CREATE OR REPLACE FUNCTION public.creer_commande(_payload jsonb)
RETURNS public.commandes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_cmd public.commandes; v_l jsonb; v_client record; v_nom text;
  v_depot uuid := public.resolve_depot_sortie(NULLIF(_payload->>'depot_id','')::uuid, 'commandes');
  v_can_valider boolean := public.has_permission_v2(auth.uid(),'commandes.valider');
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.assert_permission('commandes.creer');

  SELECT * INTO v_client FROM public.clients WHERE client_id=(_payload->>'client_id')::uuid;
  v_nom := COALESCE(v_client.nom,_payload->>'client_nom');
  INSERT INTO public.commandes(client_id,client_nom,etablissement,representant_nom,telephone,ville,adresse,
    observations,date_commande,remise_globale_pct,taux_tva,depot_id,created_by,created_by_nom,statut,numero)
  VALUES((_payload->>'client_id')::uuid,v_nom,_payload->>'etablissement',_payload->>'representant_nom',
    _payload->>'telephone',_payload->>'ville',_payload->>'adresse',_payload->>'observations',
    COALESCE((_payload->>'date_commande')::date,current_date),
    COALESCE((_payload->>'remise_globale_pct')::numeric,0),
    COALESCE((_payload->>'taux_tva')::numeric,0),v_depot,auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet',auth.jwt()->>'email'),
    'en_attente_validation','CMD-'||to_char(now(),'YYYYMMDD-HH24MISS'))
  RETURNING * INTO v_cmd;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.commande_lignes(commande_id,produit_id,reference_produit,designation,quantite,
      prix_unitaire,remise_pct,montant_remise,total_ht_ligne,total_ligne)
    VALUES(v_cmd.commande_id,NULLIF(v_l->>'produit_id','')::uuid,v_l->>'reference_produit',
      v_l->>'designation',COALESCE((v_l->>'quantite')::int,1),
      COALESCE((v_l->>'prix_unitaire')::numeric,0),COALESCE((v_l->>'remise_pct')::numeric,0),
      (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*COALESCE((v_l->>'remise_pct')::numeric,0)/100),
      (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*(1-COALESCE((v_l->>'remise_pct')::numeric,0)/100)),
      (COALESCE((v_l->>'quantite')::int,1)*COALESCE((v_l->>'prix_unitaire')::numeric,0)*(1-COALESCE((v_l->>'remise_pct')::numeric,0)/100)));
  END LOOP;

  PERFORM public.recalc_commande(v_cmd.commande_id);

  IF v_can_valider THEN
    PERFORM public.valider_commande(v_cmd.commande_id);
  END IF;

  SELECT * INTO v_cmd FROM public.commandes WHERE commande_id=v_cmd.commande_id;
  RETURN v_cmd;
END $fn$;

-- Paiements : colonnes d'audit
ALTER TABLE public.paiements
  ADD COLUMN IF NOT EXISTS valide_par uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS valide_le timestamptz,
  ADD COLUMN IF NOT EXISTS rejete_par uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS rejete_le timestamptz,
  ADD COLUMN IF NOT EXISTS motif_rejet text,
  ADD COLUMN IF NOT EXISTS commentaire_validation text,
  ADD COLUMN IF NOT EXISTS cree_par uuid REFERENCES auth.users(id);

UPDATE public.paiements
   SET valide_le = COALESCE(valide_le, created_at)
 WHERE statut = 'valide' AND valide_le IS NULL;

-- Trigger anti-doublon/surpaiement : exclut aussi les paiements rejetés
CREATE OR REPLACE FUNCTION public.trg_paiements_guard()
RETURNS trigger LANGUAGE plpgsql AS $fn$
DECLARE
  v_fac_total numeric; v_deja_paye numeric; v_reste numeric; v_doublon boolean;
BEGIN
  IF NEW.montant IS NULL OR NEW.montant <= 0 THEN
    RAISE EXCEPTION 'Montant invalide : le paiement doit être strictement positif' USING ERRCODE='check_violation';
  END IF;
  IF NEW.facture_id IS NULL THEN RETURN NEW; END IF;
  SELECT montant_total INTO v_fac_total FROM public.factures
   WHERE facture_id = NEW.facture_id FOR UPDATE;
  IF v_fac_total IS NULL THEN
    RAISE EXCEPTION 'Facture % introuvable', NEW.facture_id;
  END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.paiements
     WHERE facture_id = NEW.facture_id
       AND date_paiement = NEW.date_paiement
       AND COALESCE(mode_paiement,'') = COALESCE(NEW.mode_paiement,'')
       AND montant = NEW.montant
       AND (statut IS NULL OR statut NOT IN ('annule','rejete'))
       AND (TG_OP <> 'UPDATE' OR paiement_id <> NEW.paiement_id)
  ) INTO v_doublon;
  IF v_doublon THEN
    RAISE EXCEPTION 'Doublon de paiement détecté (facture=%, montant=%, date=%)',
      NEW.facture_id, NEW.montant, NEW.date_paiement USING ERRCODE='unique_violation';
  END IF;
  SELECT COALESCE(SUM(montant),0) INTO v_deja_paye
    FROM public.paiements
   WHERE facture_id = NEW.facture_id
     AND (statut IS NULL OR statut NOT IN ('annule','rejete'))
     AND (TG_OP <> 'UPDATE' OR paiement_id <> NEW.paiement_id);
  v_reste := v_fac_total - v_deja_paye;
  IF NEW.montant > v_reste + 0.01 THEN
    RAISE EXCEPTION 'Surpaiement interdit : reste à payer = %, tentative = %',
      v_reste, NEW.montant USING ERRCODE='check_violation';
  END IF;
  RETURN NEW;
END $fn$;

-- Force le statut selon la permission de l'utilisateur (défense en profondeur)
CREATE OR REPLACE FUNCTION public.trg_paiements_enforce_validation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.cree_par := COALESCE(NEW.cree_par, auth.uid());
    IF NEW.statut = 'valide' AND NOT public.has_permission_v2(auth.uid(),'paiements.valider') THEN
      NEW.statut := 'en_attente_validation';
    END IF;
    IF NEW.statut = 'valide' THEN
      NEW.valide_par := COALESCE(NEW.valide_par, auth.uid());
      NEW.valide_le  := COALESCE(NEW.valide_le, now());
    END IF;
  END IF;
  RETURN NEW;
END $fn$;

DROP TRIGGER IF EXISTS trg_paiements_enforce_validation ON public.paiements;
CREATE TRIGGER trg_paiements_enforce_validation
  BEFORE INSERT ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.trg_paiements_enforce_validation();

-- Fidélité : créditer aussi sur passage en_attente_validation → valide
CREATE OR REPLACE FUNCTION public.tg_paiement_fidelite()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_client_id uuid; v_points integer;
BEGIN
  SELECT client_id INTO v_client_id FROM public.factures
   WHERE facture_id = COALESCE(NEW.facture_id, OLD.facture_id);
  IF v_client_id IS NULL THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' AND NEW.statut = 'valide' THEN
    v_points := floor(NEW.montant / 1000)::int;
    IF v_points > 0 THEN
      INSERT INTO public.client_fidelite_mouvements
        (client_id, type, points, date_expiration, paiement_id, motif)
      VALUES (v_client_id, 'gain', v_points, now() + interval '24 months', NEW.paiement_id,
              'Gain automatique sur paiement ' || NEW.reference);
    END IF;
  ELSIF TG_OP = 'UPDATE' AND OLD.statut <> 'valide' AND NEW.statut = 'valide' THEN
    v_points := floor(NEW.montant / 1000)::int;
    IF v_points > 0 THEN
      INSERT INTO public.client_fidelite_mouvements
        (client_id, type, points, date_expiration, paiement_id, motif)
      VALUES (v_client_id, 'gain', v_points, now() + interval '24 months', NEW.paiement_id,
              'Gain sur validation paiement ' || NEW.reference);
    END IF;
  ELSIF TG_OP = 'UPDATE' AND OLD.statut = 'valide' AND NEW.statut <> 'valide' THEN
    SELECT COALESCE(SUM(points),0) INTO v_points
      FROM public.client_fidelite_mouvements
     WHERE paiement_id = NEW.paiement_id AND type = 'gain';
    IF v_points > 0 THEN
      INSERT INTO public.client_fidelite_mouvements
        (client_id, type, points, date_expiration, paiement_id, motif)
      VALUES (v_client_id, 'annulation', -v_points, now() + interval '24 months',
              NEW.paiement_id, 'Annulation gain paiement ' || NEW.reference);
    END IF;
  END IF;
  RETURN NEW;
END $fn$;

-- RPC : valider un paiement
CREATE OR REPLACE FUNCTION public.valider_paiement(_paiement_id uuid, _commentaire text DEFAULT NULL)
RETURNS public.paiements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_p public.paiements; v_email text;
BEGIN
  PERFORM public.assert_permission('paiements.valider');
  SELECT * INTO v_p FROM public.paiements WHERE paiement_id = _paiement_id FOR UPDATE;
  IF v_p.paiement_id IS NULL THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;
  IF v_p.statut <> 'en_attente_validation' THEN
    RAISE EXCEPTION 'Seuls les paiements en attente peuvent être validés (statut actuel: %)', v_p.statut;
  END IF;

  UPDATE public.paiements
     SET statut = 'valide',
         valide_par = auth.uid(),
         valide_le = now(),
         commentaire_validation = _commentaire,
         updated_at = now()
   WHERE paiement_id = _paiement_id
  RETURNING * INTO v_p;

  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.rbac_audit_log(user_id, user_email, action, details)
  VALUES (auth.uid(), v_email, 'paiement_valide',
          jsonb_build_object('paiement_id', _paiement_id, 'reference', v_p.reference,
                             'montant', v_p.montant, 'commentaire', _commentaire));
  RETURN v_p;
END $fn$;

-- RPC : rejeter un paiement
CREATE OR REPLACE FUNCTION public.rejeter_paiement(_paiement_id uuid, _motif text)
RETURNS public.paiements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_p public.paiements; v_email text;
BEGIN
  PERFORM public.assert_permission('paiements.valider');
  IF _motif IS NULL OR length(trim(_motif)) < 3 THEN
    RAISE EXCEPTION 'Un motif de rejet est requis (minimum 3 caractères)';
  END IF;
  SELECT * INTO v_p FROM public.paiements WHERE paiement_id = _paiement_id FOR UPDATE;
  IF v_p.paiement_id IS NULL THEN RAISE EXCEPTION 'Paiement introuvable'; END IF;
  IF v_p.statut <> 'en_attente_validation' THEN
    RAISE EXCEPTION 'Seuls les paiements en attente peuvent être rejetés (statut actuel: %)', v_p.statut;
  END IF;

  UPDATE public.paiements
     SET statut = 'rejete',
         rejete_par = auth.uid(),
         rejete_le = now(),
         motif_rejet = _motif,
         updated_at = now()
   WHERE paiement_id = _paiement_id
  RETURNING * INTO v_p;

  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  INSERT INTO public.rbac_audit_log(user_id, user_email, action, details)
  VALUES (auth.uid(), v_email, 'paiement_rejete',
          jsonb_build_object('paiement_id', _paiement_id, 'reference', v_p.reference,
                             'montant', v_p.montant, 'motif', _motif));
  RETURN v_p;
END $fn$;

GRANT EXECUTE ON FUNCTION public.valider_paiement(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rejeter_paiement(uuid, text) TO authenticated;