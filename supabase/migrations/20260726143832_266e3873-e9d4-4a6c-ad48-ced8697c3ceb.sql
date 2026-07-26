-- 1. Brouillons de documents ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.document_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid(),
  doc_type text NOT NULL,
  draft_id text NOT NULL,
  entity_id uuid,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT document_drafts_status_check CHECK (status IN ('draft','converted','abandoned')),
  CONSTRAINT document_drafts_unique UNIQUE (user_id, doc_type, draft_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_drafts TO authenticated;
GRANT ALL ON public.document_drafts TO service_role;

ALTER TABLE public.document_drafts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their own drafts" ON public.document_drafts;
CREATE POLICY "Users manage their own drafts"
ON public.document_drafts FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_document_drafts_lookup
  ON public.document_drafts (user_id, doc_type, status);

DROP TRIGGER IF EXISTS trg_document_drafts_updated_at ON public.document_drafts;
CREATE TRIGGER trg_document_drafts_updated_at
BEFORE UPDATE ON public.document_drafts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2. Idempotence -------------------------------------------------------------
ALTER TABLE public.achats     ADD COLUMN IF NOT EXISTS idempotency_key text;
ALTER TABLE public.commandes  ADD COLUMN IF NOT EXISTS idempotency_key text;
ALTER TABLE public.paiements  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS uq_achats_idempotency
  ON public.achats (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_commandes_idempotency
  ON public.commandes (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_paiements_idempotency
  ON public.paiements (idempotency_key) WHERE idempotency_key IS NOT NULL;

-- 3. Référence fournisseur automatique --------------------------------------
ALTER TABLE public.fournisseurs ADD COLUMN IF NOT EXISTS reference text;

CREATE SEQUENCE IF NOT EXISTS public.seq_fournisseur_reference START 1;

CREATE OR REPLACE FUNCTION public.generer_reference_fournisseur()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.reference IS NULL OR btrim(NEW.reference) = '' THEN
    LOOP
      NEW.reference := 'FRS-' || lpad(nextval('public.seq_fournisseur_reference')::text, 4, '0');
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.fournisseurs WHERE reference = NEW.reference
      );
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

-- Backfill des fournisseurs existants (ordre de création)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT fournisseur_id FROM public.fournisseurs
           WHERE reference IS NULL OR btrim(reference) = ''
           ORDER BY created_at, fournisseur_id LOOP
    UPDATE public.fournisseurs
      SET reference = 'FRS-' || lpad(nextval('public.seq_fournisseur_reference')::text, 4, '0')
      WHERE fournisseur_id = r.fournisseur_id;
  END LOOP;
END $$;

DROP TRIGGER IF EXISTS trg_fournisseur_reference ON public.fournisseurs;
CREATE TRIGGER trg_fournisseur_reference
BEFORE INSERT ON public.fournisseurs
FOR EACH ROW EXECUTE FUNCTION public.generer_reference_fournisseur();

CREATE UNIQUE INDEX IF NOT EXISTS uq_fournisseurs_reference
  ON public.fournisseurs (reference) WHERE reference IS NOT NULL;

-- 4. Remise par ligne d'achat -----------------------------------------------
ALTER TABLE public.achat_lignes
  ADD COLUMN IF NOT EXISTS remise_pct numeric NOT NULL DEFAULT 0;

ALTER TABLE public.achat_lignes DROP CONSTRAINT IF EXISTS achat_lignes_remise_pct_check;
ALTER TABLE public.achat_lignes
  ADD CONSTRAINT achat_lignes_remise_pct_check CHECK (remise_pct >= 0 AND remise_pct <= 100);

-- 5. RPC approvisionnement : remise + idempotence -----------------------------
CREATE OR REPLACE FUNCTION public.enregistrer_approvisionnement(_payload jsonb)
 RETURNS achats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  a public.achats;
  l jsonb;
  v_total numeric := 0;
  v_qty int := 0;
  v_depot uuid := NULLIF(_payload->>'depot_id','')::uuid;
  v_date date := COALESCE((_payload->>'date_achat')::date, current_date);
  v_qte int;
  v_actuel int;
  v_dup_count int;
  v_exercice uuid;
  v_idem text := NULLIF(_payload->>'idempotency_key','');
  v_montant_ligne numeric;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.creer') THEN
    RAISE EXCEPTION 'Permission refusée : achats.creer' USING ERRCODE = '42501';
  END IF;

  IF v_idem IS NOT NULL THEN
    SELECT * INTO a FROM public.achats WHERE idempotency_key = v_idem;
    IF FOUND THEN
      RETURN a;
    END IF;
  END IF;

  IF v_depot IS NULL THEN
    RAISE EXCEPTION 'Le dépôt est obligatoire pour un approvisionnement';
  END IF;

  SELECT COUNT(*) INTO v_dup_count FROM (
    SELECT (x->>'produit_id')::uuid AS pid
    FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) x
    WHERE NULLIF(x->>'produit_id','') IS NOT NULL
    GROUP BY (x->>'produit_id')::uuid
    HAVING COUNT(*) > 1
  ) d;
  IF v_dup_count > 0 THEN
    RAISE EXCEPTION 'Un même produit ne peut pas être ajouté plusieurs fois dans un approvisionnement';
  END IF;

  SELECT exercice_id INTO v_exercice
  FROM public.exercices_comptables
  WHERE v_date BETWEEN date_debut AND date_fin
  ORDER BY (statut = 'actif') DESC LIMIT 1;

  IF v_exercice IS NULL THEN
    SELECT exercice_id INTO v_exercice FROM public.exercices_comptables WHERE statut = 'actif' LIMIT 1;
  END IF;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_total := v_total + ROUND(
      COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0)
      * (1 - COALESCE((l->>'remise_pct')::numeric,0) / 100), 2);
    v_qty := v_qty + COALESCE((l->>'quantite')::int,0);
  END LOOP;

  INSERT INTO public.achats(fournisseur_id, fournisseur_nom, libelle, montant, statut, date_achat,
    reference_fournisseur, notes, total_quantite, depot_id, exercice_id, created_by, created_by_nom,
    idempotency_key)
  SELECT (_payload->>'fournisseur_id')::uuid, f.raison_sociale, 'Approvisionnement', v_total, 'recu',
    v_date, _payload->>'reference_fournisseur', _payload->>'notes', v_qty, v_depot, v_exercice, auth.uid(),
    COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email'), v_idem
  FROM public.fournisseurs f
  WHERE f.fournisseur_id = (_payload->>'fournisseur_id')::uuid
  RETURNING * INTO a;

  FOR l IN SELECT * FROM jsonb_array_elements(COALESCE(_payload->'lignes','[]'::jsonb)) LOOP
    v_montant_ligne := ROUND(
      COALESCE((l->>'quantite')::int,0) * COALESCE((l->>'prix_unitaire')::numeric,0)
      * (1 - COALESCE((l->>'remise_pct')::numeric,0) / 100), 2);

    INSERT INTO public.achat_lignes(achat_id, produit_id, reference_produit, designation,
      quantite, prix_unitaire, remise_pct, total_ligne)
    VALUES(a.achat_id, NULLIF(l->>'produit_id','')::uuid, l->>'reference_produit', l->>'designation',
      COALESCE((l->>'quantite')::int,0), COALESCE((l->>'prix_unitaire')::numeric,0),
      LEAST(GREATEST(COALESCE((l->>'remise_pct')::numeric,0),0),100), v_montant_ligne);

    IF NULLIF(l->>'produit_id','') IS NOT NULL THEN
      v_qte := COALESCE((l->>'quantite')::int,0);
      INSERT INTO public.stocks_depots(produit_id, depot_id, quantite)
      VALUES((l->>'produit_id')::uuid, v_depot, 0)
      ON CONFLICT (produit_id, depot_id) DO NOTHING;
      SELECT quantite INTO v_actuel FROM public.stocks_depots
        WHERE produit_id = (l->>'produit_id')::uuid AND depot_id = v_depot FOR UPDATE;
      PERFORM public.ajuster_stock_depot(
        (l->>'produit_id')::uuid, v_depot,
        (COALESCE(v_actuel,0) + v_qte)::numeric,
        'Approvisionnement ' || a.reference
      );
    END IF;
  END LOOP;

  RETURN a;
END
$function$;

CREATE OR REPLACE FUNCTION public.modifier_approvisionnement(_achat_id uuid, _payload jsonb)
 RETURNS SETOF achats
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_ligne jsonb; v_total numeric := 0; v_montant_ligne numeric;
BEGIN
  IF NOT public.has_permission(auth.uid(), 'achats.modifier') THEN
    RAISE EXCEPTION 'Permission refusée : achats.modifier' USING ERRCODE = '42501';
  END IF;

  UPDATE public.achats SET
    fournisseur_id = COALESCE(NULLIF(_payload->>'fournisseur_id','')::uuid, fournisseur_id),
    depot_id = COALESCE(NULLIF(_payload->>'depot_id','')::uuid, depot_id),
    libelle = COALESCE(_payload->>'libelle', libelle),
    date_achat = COALESCE((_payload->>'date_achat')::date, date_achat),
    notes = COALESCE(_payload->>'notes', notes)
  WHERE achat_id = _achat_id;

  IF _payload ? 'lignes' THEN
    DELETE FROM public.achat_lignes WHERE achat_id = _achat_id;
    FOR v_ligne IN SELECT * FROM jsonb_array_elements(_payload->'lignes') LOOP
      v_montant_ligne := ROUND(
        COALESCE((v_ligne->>'quantite')::numeric,0) * COALESCE((v_ligne->>'prix_unitaire')::numeric,0)
        * (1 - COALESCE((v_ligne->>'remise_pct')::numeric,0) / 100), 2);

      INSERT INTO public.achat_lignes(achat_id, produit_id, reference_produit, designation,
        quantite, prix_unitaire, remise_pct, total_ligne)
      VALUES (_achat_id,
        NULLIF(v_ligne->>'produit_id','')::uuid,
        v_ligne->>'reference_produit',
        COALESCE(v_ligne->>'designation',''),
        COALESCE((v_ligne->>'quantite')::numeric, 0),
        COALESCE((v_ligne->>'prix_unitaire')::numeric, 0),
        LEAST(GREATEST(COALESCE((v_ligne->>'remise_pct')::numeric,0),0),100),
        v_montant_ligne);
      v_total := v_total + v_montant_ligne;
    END LOOP;
    UPDATE public.achats SET montant = v_total WHERE achat_id = _achat_id;
  END IF;

  RETURN QUERY SELECT * FROM public.achats WHERE achat_id = _achat_id;
END; $function$;