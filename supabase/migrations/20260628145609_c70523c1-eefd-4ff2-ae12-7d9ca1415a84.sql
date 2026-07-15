
-- 1. DEPOTS
CREATE TABLE public.depots (
  depot_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  nom text NOT NULL,
  adresse text,
  responsable text,
  telephone text,
  actif boolean NOT NULL DEFAULT true,
  is_principal boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX depots_one_principal ON public.depots (is_principal) WHERE is_principal = true;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.depots TO authenticated;
GRANT ALL ON public.depots TO service_role;
ALTER TABLE public.depots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "depots_read_auth" ON public.depots FOR SELECT TO authenticated USING (true);
CREATE POLICY "depots_write_staff" ON public.depots FOR ALL TO authenticated
  USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER depots_updated BEFORE UPDATE ON public.depots
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2. STOCKS PAR DEPOT
CREATE TABLE public.stocks_depots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id) ON DELETE CASCADE,
  depot_id uuid NOT NULL REFERENCES public.depots(depot_id) ON DELETE CASCADE,
  quantite integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (produit_id, depot_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stocks_depots TO authenticated;
GRANT ALL ON public.stocks_depots TO service_role;
ALTER TABLE public.stocks_depots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sd_read_auth" ON public.stocks_depots FOR SELECT TO authenticated USING (true);
CREATE POLICY "sd_write_staff" ON public.stocks_depots FOR ALL TO authenticated
  USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER sd_updated BEFORE UPDATE ON public.stocks_depots
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 3. TRANSFERTS
CREATE TABLE public.transferts (
  transfert_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero text UNIQUE NOT NULL,
  depot_source_id uuid NOT NULL REFERENCES public.depots(depot_id),
  depot_destination_id uuid NOT NULL REFERENCES public.depots(depot_id),
  statut text NOT NULL DEFAULT 'brouillon' CHECK (statut IN ('brouillon','expedie','recu','annule')),
  date_creation timestamptz NOT NULL DEFAULT now(),
  date_expedition timestamptz,
  date_reception timestamptz,
  transporteur text,
  motif text,
  notes text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (depot_source_id <> depot_destination_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transferts TO authenticated;
GRANT ALL ON public.transferts TO service_role;
ALTER TABLE public.transferts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tr_read_auth" ON public.transferts FOR SELECT TO authenticated USING (true);
CREATE POLICY "tr_write_staff" ON public.transferts FOR ALL TO authenticated
  USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER tr_updated BEFORE UPDATE ON public.transferts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 4. LIGNES TRANSFERT
CREATE TABLE public.transfert_lignes (
  ligne_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfert_id uuid NOT NULL REFERENCES public.transferts(transfert_id) ON DELETE CASCADE,
  produit_id uuid NOT NULL REFERENCES public.produits(produit_id),
  quantite integer NOT NULL CHECK (quantite > 0),
  quantite_recue integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX trl_transfert_idx ON public.transfert_lignes(transfert_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transfert_lignes TO authenticated;
GRANT ALL ON public.transfert_lignes TO service_role;
ALTER TABLE public.transfert_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "trl_read_auth" ON public.transfert_lignes FOR SELECT TO authenticated USING (true);
CREATE POLICY "trl_write_staff" ON public.transfert_lignes FOR ALL TO authenticated
  USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

-- 5. stock_mouvements: ajout depot_id
ALTER TABLE public.stock_mouvements ADD COLUMN IF NOT EXISTS depot_id uuid REFERENCES public.depots(depot_id);

-- 6. Dépôt principal par défaut + initialiser stocks_depots
INSERT INTO public.depots (code, nom, is_principal) VALUES ('DEP-PRINCIPAL', 'Dépôt Principal', true);

INSERT INTO public.stocks_depots (produit_id, depot_id, quantite)
SELECT p.produit_id, d.depot_id, COALESCE(p.stock, 0)
FROM public.produits p
CROSS JOIN public.depots d
WHERE d.is_principal = true;

-- 7. Trigger mis à jour: met à jour stocks_depots ET produits.stock (somme)
CREATE OR REPLACE FUNCTION public.apply_stock_mouvement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_depot uuid;
  v_current integer;
  v_new integer;
  v_total integer;
BEGIN
  -- dépôt cible: NEW.depot_id ou dépôt principal
  v_depot := NEW.depot_id;
  IF v_depot IS NULL THEN
    SELECT depot_id INTO v_depot FROM public.depots WHERE is_principal = true LIMIT 1;
    NEW.depot_id := v_depot;
  END IF;

  -- assurer existence de la ligne
  INSERT INTO public.stocks_depots (produit_id, depot_id, quantite)
  VALUES (NEW.produit_id, v_depot, 0)
  ON CONFLICT (produit_id, depot_id) DO NOTHING;

  SELECT quantite INTO v_current FROM public.stocks_depots
    WHERE produit_id = NEW.produit_id AND depot_id = v_depot FOR UPDATE;

  IF NEW.type IN ('entree','transfert_entree') THEN
    v_new := v_current + NEW.quantite;
  ELSIF NEW.type IN ('sortie','transfert_sortie') THEN
    v_new := v_current - NEW.quantite;
  ELSE
    v_new := NEW.quantite; -- ajustement
  END IF;
  IF v_new < 0 THEN v_new := 0; END IF;

  UPDATE public.stocks_depots SET quantite = v_new, updated_at = now()
    WHERE produit_id = NEW.produit_id AND depot_id = v_depot;

  SELECT COALESCE(SUM(quantite),0) INTO v_total FROM public.stocks_depots
    WHERE produit_id = NEW.produit_id;
  UPDATE public.produits SET stock = v_total, updated_at = now()
    WHERE produit_id = NEW.produit_id;

  NEW.stock_resultant := v_total;
  RETURN NEW;
END;
$$;

-- 8. Exécution d'un transfert (sortie + entrée)
CREATE OR REPLACE FUNCTION public.executer_transfert(_transfert_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  t record;
  l record;
BEGIN
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
    SET statut = 'expedie', date_expedition = now(), date_reception = now()
    WHERE transfert_id = _transfert_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.receptionner_transfert(_transfert_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.transferts SET statut = 'recu', date_reception = now()
    WHERE transfert_id = _transfert_id AND statut = 'expedie';
END;
$$;

CREATE OR REPLACE FUNCTION public.annuler_transfert(_transfert_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.transferts SET statut = 'annule'
    WHERE transfert_id = _transfert_id AND statut = 'brouillon';
END;
$$;
