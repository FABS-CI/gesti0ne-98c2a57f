
-- Colonnes preuves & séquencement sur livsuivi_commandes
ALTER TABLE public.livsuivi_commandes
  ADD COLUMN IF NOT EXISTS ordre_passage int,
  ADD COLUMN IF NOT EXISTS point_livraison text,
  ADD COLUMN IF NOT EXISTS heure_depart timestamptz,
  ADD COLUMN IF NOT EXISTS heure_arrivee timestamptz,
  ADD COLUMN IF NOT EXISTS heure_livraison timestamptz,
  ADD COLUMN IF NOT EXISTS receptionnaire_telephone text,
  ADD COLUMN IF NOT EXISTS signature_url text,
  ADD COLUMN IF NOT EXISTS photo_preuve_url text,
  ADD COLUMN IF NOT EXISTS commentaire_reception text,
  ADD COLUMN IF NOT EXISTS retour_motif text;

-- Trigger : quand toutes les livraisons d'une tournée sont livrees / reception_confirmee / livree_locale / non_livre,
-- la tournée passe à 'terminee'. Sinon elle reste 'en_cours'.
CREATE OR REPLACE FUNCTION public.check_tournee_all_livrees()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tournee_id uuid;
  v_pending int;
  v_total int;
BEGIN
  v_tournee_id := COALESCE(NEW.tournee_id, OLD.tournee_id);
  IF v_tournee_id IS NULL THEN RETURN NEW; END IF;

  SELECT count(*) FILTER (WHERE statut NOT IN ('livree','reception_confirmee','livree_locale','retiree_client','non_livre')),
         count(*)
    INTO v_pending, v_total
    FROM public.livsuivi_commandes
   WHERE tournee_id = v_tournee_id;

  IF v_total > 0 AND v_pending = 0 THEN
    UPDATE public.tournees
       SET statut = 'terminee', updated_at = now()
     WHERE tournee_id = v_tournee_id AND statut <> 'terminee';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_tournee_all_livrees ON public.livsuivi_commandes;
CREATE TRIGGER trg_check_tournee_all_livrees
AFTER UPDATE OF statut ON public.livsuivi_commandes
FOR EACH ROW
WHEN (NEW.statut IS DISTINCT FROM OLD.statut)
EXECUTE FUNCTION public.check_tournee_all_livrees();

-- RPC : confirmation de réception avec preuves
CREATE OR REPLACE FUNCTION public.livsuivi_confirmer_reception(
  _id uuid,
  _signature_url text DEFAULT NULL,
  _photo_url text DEFAULT NULL,
  _receptionnaire_nom text DEFAULT NULL,
  _receptionnaire_tel text DEFAULT NULL,
  _commentaire text DEFAULT NULL
)
RETURNS public.livsuivi_commandes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.livsuivi_commandes;
  v_user text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  PERFORM public.assert_permission('livsuivi.avancer');

  SELECT COALESCE(nom_complet, email, auth.uid()::text) INTO v_user
    FROM public.profiles WHERE user_id = auth.uid();

  UPDATE public.livsuivi_commandes
     SET statut = 'reception_confirmee'::public.livsuivi_statut,
         signature_url = COALESCE(_signature_url, signature_url),
         photo_preuve_url = COALESCE(_photo_url, photo_preuve_url),
         receptionnaire_nom = COALESCE(_receptionnaire_nom, receptionnaire_nom),
         receptionnaire_telephone = COALESCE(_receptionnaire_tel, receptionnaire_telephone),
         commentaire_reception = COALESCE(_commentaire, commentaire_reception),
         heure_livraison = COALESCE(heure_livraison, now()),
         derniere_maj = now(),
         cloturee = true
   WHERE id = _id
  RETURNING * INTO v_row;
  IF NOT FOUND THEN RAISE EXCEPTION 'Livraison introuvable'; END IF;

  INSERT INTO public.livsuivi_historique(livraison_id, etape, commentaire, meta, user_nom)
  VALUES (
    _id,
    'reception_confirmee'::public.livsuivi_statut,
    _commentaire,
    jsonb_strip_nulls(jsonb_build_object(
      'signature_url', _signature_url,
      'photo_preuve_url', _photo_url,
      'receptionnaire_nom', _receptionnaire_nom,
      'receptionnaire_telephone', _receptionnaire_tel
    )),
    v_user
  );

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.livsuivi_confirmer_reception(uuid,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.livsuivi_confirmer_reception(uuid,text,text,text,text,text) TO authenticated;
