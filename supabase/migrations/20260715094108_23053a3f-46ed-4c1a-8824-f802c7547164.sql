-- 1) TABLE avoirs
CREATE SEQUENCE IF NOT EXISTS public.avoirs_ref_seq START 1;

CREATE TABLE IF NOT EXISTS public.avoirs (
  avoir_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference           text NOT NULL UNIQUE
                        DEFAULT ('AV-' || to_char(now(),'YYYY') || '-' ||
                                 lpad(nextval('public.avoirs_ref_seq')::text, 5, '0')),
  retour_id           uuid REFERENCES public.retours(retour_id) ON DELETE SET NULL,
  br_id               uuid REFERENCES public.bons_retour(br_id) ON DELETE SET NULL,
  facture_id          uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  client_id           uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  client_nom          text,
  date_emission       date NOT NULL DEFAULT CURRENT_DATE,
  montant             numeric(14,2) NOT NULL DEFAULT 0 CHECK (montant >= 0),
  statut              text NOT NULL DEFAULT 'emis'
                        CHECK (statut IN ('emis','impute','rembourse','annule')),
  mode_reglement      text,
  date_reglement      date,
  facture_imputee_id  uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  paiement_id         uuid REFERENCES public.paiements(paiement_id) ON DELETE SET NULL,
  notes               text,
  exercice_id         uuid REFERENCES public.exercices(exercice_id) ON DELETE RESTRICT,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_avoirs_retour   ON public.avoirs(retour_id);
CREATE INDEX IF NOT EXISTS idx_avoirs_facture  ON public.avoirs(facture_id);
CREATE INDEX IF NOT EXISTS idx_avoirs_client   ON public.avoirs(client_id);
CREATE INDEX IF NOT EXISTS idx_avoirs_statut   ON public.avoirs(statut);
CREATE INDEX IF NOT EXISTS idx_avoirs_exercice ON public.avoirs(exercice_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.avoirs TO authenticated;
GRANT ALL ON public.avoirs TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.avoirs_ref_seq TO authenticated;
GRANT ALL ON SEQUENCE public.avoirs_ref_seq TO service_role;

ALTER TABLE public.avoirs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth read avoirs" ON public.avoirs;
CREATE POLICY "auth read avoirs" ON public.avoirs FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "auth write avoirs" ON public.avoirs;
CREATE POLICY "auth write avoirs" ON public.avoirs FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2) LIVRAISONS — colonnes manquantes
ALTER TABLE public.livraisons
  ADD COLUMN IF NOT EXISTS client_id        uuid REFERENCES public.clients(client_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS expedition_id    uuid REFERENCES public.expeditions(expedition_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS bl_id            uuid REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS livreur_id       uuid REFERENCES public.livreurs(livreur_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS transporteur_id  uuid REFERENCES public.transporteurs(transporteur_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS gare_depart_id   uuid REFERENCES public.gares(gare_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS gare_arrivee_id  uuid REFERENCES public.gares(gare_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ville            text,
  ADD COLUMN IF NOT EXISTS commune          text,
  ADD COLUMN IF NOT EXISTS telephone_dest   text,
  ADD COLUMN IF NOT EXISTS contact_dest     text,
  ADD COLUMN IF NOT EXISTS figee            boolean NOT NULL DEFAULT false;

-- 3) RETOURS — colonnes de liaison
ALTER TABLE public.retours
  ADD COLUMN IF NOT EXISTS facture_id  uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS commande_id uuid REFERENCES public.commandes(commande_id) ON DELETE SET NULL;

-- 4) RPC stubs
CREATE OR REPLACE FUNCTION public.creer_inventaire_theorique(_payload jsonb DEFAULT '{}'::jsonb)
RETURNS public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.inventaires;
BEGIN
  INSERT INTO public.inventaires(numero, type_inventaire, date_inventaire, statut, observations)
  VALUES('INV-'||to_char(now(),'YYYYMMDD-HH24MISS'), 'theorique', current_date, 'brouillon',
         COALESCE(_payload->>'observations',''))
  RETURNING * INTO r;
  RETURN r;
END $$;
GRANT EXECUTE ON FUNCTION public.creer_inventaire_theorique(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.creer_inventaire_global(_payload jsonb DEFAULT '{}'::jsonb)
RETURNS public.inventaires LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.inventaires;
BEGIN
  INSERT INTO public.inventaires(numero, type_inventaire, date_inventaire, statut, observations)
  VALUES('INV-'||to_char(now(),'YYYYMMDD-HH24MISS'), 'global', current_date, 'brouillon',
         COALESCE(_payload->>'observations',''))
  RETURNING * INTO r;
  RETURN r;
END $$;
GRANT EXECUTE ON FUNCTION public.creer_inventaire_global(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.rapport_produits(
  _filtres jsonb DEFAULT '{}'::jsonb, _tri text DEFAULT 'ca', _sens text DEFAULT 'desc',
  _limit int DEFAULT 100, _offset int DEFAULT 0
) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$ SELECT jsonb_build_object('total',0,'ca_total',0,'items','[]'::jsonb) $$;
GRANT EXECUTE ON FUNCTION public.rapport_produits(jsonb,text,text,int,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.rapport_kpi(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$ SELECT jsonb_build_object(
  'qte_vendue',0,'qte_facturee',0,'nb_factures',0,'nb_clients',0,'ca',0,
  'nb_commandes',0,'prix_moyen',0,'panier_moyen',0,
  'top_produit',null,'rentable_produit',null,'flop_produit',null) $$;
GRANT EXECUTE ON FUNCTION public.rapport_kpi(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.rapport_top_produits(_filtres jsonb DEFAULT '{}'::jsonb, _limit int DEFAULT 20)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$ SELECT '[]'::jsonb $$;
GRANT EXECUTE ON FUNCTION public.rapport_top_produits(jsonb,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.rapport_flop_produits(_filtres jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$ SELECT jsonb_build_object('jamais_vendus','[]'::jsonb,'peu_vendus','[]'::jsonb) $$;
GRANT EXECUTE ON FUNCTION public.rapport_flop_produits(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.rapport_agregat(_filtres jsonb DEFAULT '{}'::jsonb, _dim text DEFAULT 'niveau')
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$ SELECT '[]'::jsonb $$;
GRANT EXECUTE ON FUNCTION public.rapport_agregat(jsonb,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.rapport_clients_produit(_produit_id uuid, _filtres jsonb DEFAULT '{}'::jsonb, _limit int DEFAULT 100)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$ SELECT '[]'::jsonb $$;
GRANT EXECUTE ON FUNCTION public.rapport_clients_produit(uuid,jsonb,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.rapport_evolution(_filtres jsonb DEFAULT '{}'::jsonb, _granularite text DEFAULT 'mois')
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$ SELECT '[]'::jsonb $$;
GRANT EXECUTE ON FUNCTION public.rapport_evolution(jsonb,text) TO authenticated;