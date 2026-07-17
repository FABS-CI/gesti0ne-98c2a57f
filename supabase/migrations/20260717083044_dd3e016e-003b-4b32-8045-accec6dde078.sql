
-- ============================================================================
-- RETOURS : compléter les colonnes attendues par le frontend
-- ============================================================================
ALTER TABLE public.retours
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS etablissement text,
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS depot_id uuid,
  ADD COLUMN IF NOT EXISTS total_quantite numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_produits int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS livraison_id uuid,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_by_nom text,
  ADD COLUMN IF NOT EXISTS exercice_id uuid;

ALTER TABLE public.retour_lignes
  ADD COLUMN IF NOT EXISTS reference_produit text;

-- Trigger d'auto-résolution d'exercice (déjà défini globalement mais on l'attache aussi ici)
DROP TRIGGER IF EXISTS trg_set_exercice_id ON public.retours;
CREATE TRIGGER trg_set_exercice_id
  BEFORE INSERT ON public.retours
  FOR EACH ROW EXECUTE FUNCTION public._set_exercice_id_before_insert();

-- Réécriture de creer_retour avec toutes les colonnes attendues
CREATE OR REPLACE FUNCTION public.creer_retour(_payload jsonb)
 RETURNS SETOF public.retours
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('RET','public.retours','reference');
  v_num text := v_ref;
  v_l jsonb;
  v_qte_totale numeric := 0;
  v_nb_produits int := 0;
  v_montant numeric := 0;
  v_client_nom text;
  v_created_by_nom text;
  v_commande_id uuid;
BEGIN
  -- Nom client automatique
  IF NULLIF(_payload->>'client_id','') IS NOT NULL THEN
    SELECT nom INTO v_client_nom FROM public.clients WHERE client_id = (_payload->>'client_id')::uuid;
  END IF;

  -- Nom utilisateur
  v_created_by_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  -- Si rattaché à une facture, on récupère la commande liée
  IF NULLIF(_payload->>'facture_id','') IS NOT NULL THEN
    SELECT commande_id INTO v_commande_id
    FROM public.factures WHERE facture_id = (_payload->>'facture_id')::uuid;
  END IF;

  INSERT INTO public.retours(
    reference, numero, commande_id, client_id, client_nom, facture_id, livraison_id,
    etablissement, representant_nom, telephone, ville, adresse, depot_id,
    date_retour, statut, motif, notes, observations,
    total_quantite, nb_produits, montant,
    created_by, created_by_nom
  ) VALUES (
    v_ref, v_num, v_commande_id,
    NULLIF(_payload->>'client_id','')::uuid,
    COALESCE(_payload->>'client_nom', v_client_nom),
    NULLIF(_payload->>'facture_id','')::uuid,
    NULLIF(_payload->>'livraison_id','')::uuid,
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    NULLIF(_payload->>'depot_id','')::uuid,
    COALESCE((_payload->>'date_retour')::date, current_date),
    'accepte',
    _payload->>'motif',
    _payload->>'notes',
    _payload->>'observations',
    0, 0, 0,
    auth.uid(), v_created_by_nom
  )
  RETURNING retour_id INTO v_id;

  -- Lignes
  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.retour_lignes(
      retour_id, produit_id, reference_produit, designation, quantite, motif
    ) VALUES (
      v_id,
      NULLIF(v_l->>'produit_id','')::uuid,
      v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''),
      COALESCE((v_l->>'quantite')::numeric, 0),
      v_l->>'motif'
    );
    v_qte_totale := v_qte_totale + COALESCE((v_l->>'quantite')::numeric, 0);
    v_nb_produits := v_nb_produits + 1;
  END LOOP;

  -- Totaux
  UPDATE public.retours
     SET total_quantite = v_qte_totale,
         nb_produits    = v_nb_produits
   WHERE retour_id = v_id;

  RETURN QUERY SELECT * FROM public.retours WHERE retour_id = v_id;
END;
$function$;

-- ============================================================================
-- SPECIMENS : compléter les colonnes + créer specimen_lignes
-- ============================================================================
ALTER TABLE public.specimens
  ADD COLUMN IF NOT EXISTS numero text,
  ADD COLUMN IF NOT EXISTS etablissement text,
  ADD COLUMN IF NOT EXISTS representant_nom text,
  ADD COLUMN IF NOT EXISTS telephone text,
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS adresse text,
  ADD COLUMN IF NOT EXISTS donneur_nom text,
  ADD COLUMN IF NOT EXISTS motif text,
  ADD COLUMN IF NOT EXISTS observations text,
  ADD COLUMN IF NOT EXISTS gestionnaire_id uuid,
  ADD COLUMN IF NOT EXISTS gestionnaire_nom text,
  ADD COLUMN IF NOT EXISTS total_quantite numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_produits int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS depot_id uuid,
  ADD COLUMN IF NOT EXISTS exercice_id uuid;

DROP TRIGGER IF EXISTS trg_set_exercice_id ON public.specimens;
CREATE TRIGGER trg_set_exercice_id
  BEFORE INSERT ON public.specimens
  FOR EACH ROW EXECUTE FUNCTION public._set_exercice_id_before_insert();

-- Table specimen_lignes
CREATE TABLE IF NOT EXISTS public.specimen_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  specimen_id uuid NOT NULL REFERENCES public.specimens(specimen_id) ON DELETE CASCADE,
  produit_id uuid,
  reference_produit text,
  designation text NOT NULL DEFAULT '',
  quantite numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.specimen_lignes TO authenticated;
GRANT ALL ON public.specimen_lignes TO service_role;

ALTER TABLE public.specimen_lignes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "specimen_lignes_read_auth" ON public.specimen_lignes;
CREATE POLICY "specimen_lignes_read_auth" ON public.specimen_lignes
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "specimen_lignes_write_auth" ON public.specimen_lignes;
CREATE POLICY "specimen_lignes_write_auth" ON public.specimen_lignes
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_specimen_lignes_specimen_id ON public.specimen_lignes(specimen_id);

-- Réécriture de creer_specimen avec lignes multiples
CREATE OR REPLACE FUNCTION public.creer_specimen(_payload jsonb)
 RETURNS SETOF public.specimens
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_ref text := public._next_ref('SPC','public.specimens','reference');
  v_num text := v_ref;
  v_l jsonb;
  v_qte_totale numeric := 0;
  v_nb_produits int := 0;
  v_client_nom text;
  v_created_by_nom text;
BEGIN
  IF NULLIF(_payload->>'client_id','') IS NOT NULL THEN
    SELECT nom INTO v_client_nom FROM public.clients WHERE client_id = (_payload->>'client_id')::uuid;
  END IF;
  v_created_by_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  INSERT INTO public.specimens(
    reference, numero, client_id, client_nom,
    etablissement, representant_nom, telephone, ville, adresse,
    donneur_nom, motif, observations,
    date_envoi, statut,
    total_quantite, nb_produits,
    depot_id, created_by,
    gestionnaire_id, gestionnaire_nom,
    quantite, designation
  ) VALUES (
    v_ref, v_num,
    NULLIF(_payload->>'client_id','')::uuid,
    COALESCE(_payload->>'client_nom', v_client_nom),
    _payload->>'etablissement',
    _payload->>'representant_nom',
    _payload->>'telephone',
    _payload->>'ville',
    _payload->>'adresse',
    _payload->>'donneur_nom',
    _payload->>'motif',
    _payload->>'observations',
    COALESCE((_payload->>'date_envoi')::date, current_date),
    'enregistre',
    0, 0,
    NULLIF(_payload->>'depot_id','')::uuid,
    auth.uid(),
    auth.uid(), v_created_by_nom,
    0, ''  -- legacy columns (quantite/designation) conservées, mises à défaut
  )
  RETURNING specimen_id INTO v_id;

  FOR v_l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    INSERT INTO public.specimen_lignes(
      specimen_id, produit_id, reference_produit, designation, quantite
    ) VALUES (
      v_id,
      NULLIF(v_l->>'produit_id','')::uuid,
      v_l->>'reference_produit',
      COALESCE(v_l->>'designation',''),
      COALESCE((v_l->>'quantite')::numeric, 0)
    );
    v_qte_totale := v_qte_totale + COALESCE((v_l->>'quantite')::numeric, 0);
    v_nb_produits := v_nb_produits + 1;
  END LOOP;

  UPDATE public.specimens
     SET total_quantite = v_qte_totale,
         nb_produits    = v_nb_produits
   WHERE specimen_id = v_id;

  RETURN QUERY SELECT * FROM public.specimens WHERE specimen_id = v_id;
END;
$function$;
