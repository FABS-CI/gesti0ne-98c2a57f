CREATE TABLE IF NOT EXISTS public.livraisons_commande (
  livraison_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commande_id           uuid NOT NULL UNIQUE REFERENCES public.commandes(commande_id) ON DELETE CASCADE,
  bl_id                 uuid REFERENCES public.bons_livraison(bl_id) ON DELETE SET NULL,
  tournee_id            uuid REFERENCES public.tournees(tournee_id) ON DELETE SET NULL,
  statut                public.statut_livraison_cmd NOT NULL DEFAULT 'commande_creee',
  type_livraison        text,
  gare_nom              text,
  ville_livraison       text,
  transporteur          text,
  chauffeur_nom         text,
  vehicule              text,
  nb_cartons            integer NOT NULL DEFAULT 0,
  quantite_commandee    integer NOT NULL DEFAULT 0,
  quantite_preparee     integer NOT NULL DEFAULT 0,
  quantite_expediee     integer NOT NULL DEFAULT 0,
  quantite_livree       integer NOT NULL DEFAULT 0,
  progression_pct       integer NOT NULL DEFAULT 0,
  date_confirmation     timestamptz,
  date_expedition       timestamptz,
  date_prevue_livraison date,
  date_livraison        timestamptz,
  anomalie_motif        text,
  observations          text,
  derniere_maj          timestamptz NOT NULL DEFAULT now(),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_livcmd_tournee ON public.livraisons_commande(tournee_id);
CREATE INDEX IF NOT EXISTS idx_livcmd_statut  ON public.livraisons_commande(statut);
CREATE INDEX IF NOT EXISTS idx_livcmd_ville   ON public.livraisons_commande(ville_livraison);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.livraisons_commande TO authenticated;
GRANT ALL ON public.livraisons_commande TO service_role;

ALTER TABLE public.livraisons_commande ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth read livcmd" ON public.livraisons_commande;
CREATE POLICY "auth read livcmd" ON public.livraisons_commande FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "auth write livcmd" ON public.livraisons_commande;
CREATE POLICY "auth write livcmd" ON public.livraisons_commande FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.commandes
  ADD COLUMN IF NOT EXISTS depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_commandes_depot ON public.commandes(depot_id);

ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS new_values jsonb,
  ADD COLUMN IF NOT EXISTS old_values jsonb;