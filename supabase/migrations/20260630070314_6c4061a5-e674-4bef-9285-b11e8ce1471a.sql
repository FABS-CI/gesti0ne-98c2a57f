
-- 1. Colonnes statut logistique + horodatages
ALTER TABLE public.colis
  ADD COLUMN IF NOT EXISTS statut_logistique text NOT NULL DEFAULT 'prepare',
  ADD COLUMN IF NOT EXISTS date_remise_livreur timestamptz,
  ADD COLUMN IF NOT EXISTS date_depart timestamptz,
  ADD COLUMN IF NOT EXISTS date_arrivee_estimee timestamptz,
  ADD COLUMN IF NOT EXISTS date_arrivee_client timestamptz,
  ADD COLUMN IF NOT EXISTS date_livraison_reelle timestamptz,
  ADD COLUMN IF NOT EXISTS date_depot_gare timestamptz,
  ADD COLUMN IF NOT EXISTS date_arrivee_ville timestamptz,
  ADD COLUMN IF NOT EXISTS date_remise_client timestamptz;

-- 2. Historique des statuts
CREATE TABLE IF NOT EXISTS public.colis_statut_historique (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  colis_id uuid NOT NULL REFERENCES public.colis(colis_id) ON DELETE CASCADE,
  mode_acheminement text NOT NULL,
  ancien_statut text,
  nouveau_statut text NOT NULL,
  commentaire text,
  user_id uuid,
  user_nom text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.colis_statut_historique TO authenticated;
GRANT ALL ON public.colis_statut_historique TO service_role;

ALTER TABLE public.colis_statut_historique ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authentifies peuvent lire historique colis" ON public.colis_statut_historique;
CREATE POLICY "Authentifies peuvent lire historique colis"
  ON public.colis_statut_historique FOR SELECT
  TO authenticated USING (true);

-- Pas de policy INSERT/UPDATE/DELETE: tout passe par la fonction SECURITY DEFINER.

CREATE INDEX IF NOT EXISTS idx_colis_statut_historique_colis ON public.colis_statut_historique(colis_id, created_at DESC);

-- 3. Trigger anti-suppression
CREATE OR REPLACE FUNCTION public.guard_colis_historique_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  RAISE EXCEPTION 'Historique de suivi non modifiable';
END $$;

DROP TRIGGER IF EXISTS trg_colis_historique_no_delete ON public.colis_statut_historique;
CREATE TRIGGER trg_colis_historique_no_delete
  BEFORE DELETE OR UPDATE ON public.colis_statut_historique
  FOR EACH ROW EXECUTE FUNCTION public.guard_colis_historique_immutable();

-- 4. Fonction de changement de statut
CREATE OR REPLACE FUNCTION public.changer_statut_colis(
  _colis_id uuid,
  _nouveau_statut text,
  _commentaire text DEFAULT NULL
) RETURNS public.colis
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  c public.colis;
  v_mode text;
  v_current text;
  v_next_allowed text[];
  v_user_nom text;
  v_update_col text;
  v_bl_status text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF NOT public.has_any_role(auth.uid(),
        ARRAY['super_admin','directeur_general','service_logistique']::app_role[]) THEN
    RAISE EXCEPTION 'Permission refusée pour modifier le statut logistique';
  END IF;

  SELECT * INTO c FROM public.colis WHERE colis_id = _colis_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Colis introuvable'; END IF;

  v_mode := COALESCE(c.mode_acheminement, 'livraison');
  v_current := COALESCE(c.statut_logistique, 'prepare');

  IF v_mode = 'livraison' THEN
    v_next_allowed := CASE v_current
      WHEN 'prepare' THEN ARRAY['remis_livreur']
      WHEN 'remis_livreur' THEN ARRAY['en_cours_livraison']
      WHEN 'en_cours_livraison' THEN ARRAY['arrive_client']
      WHEN 'arrive_client' THEN ARRAY['livre']
      ELSE ARRAY[]::text[]
    END;
  ELSE
    v_next_allowed := CASE v_current
      WHEN 'prepare' THEN ARRAY['depose_gare']
      WHEN 'depose_gare' THEN ARRAY['en_cours_expedition']
      WHEN 'en_cours_expedition' THEN ARRAY['arrive_ville']
      WHEN 'arrive_ville' THEN ARRAY['remis_client']
      ELSE ARRAY[]::text[]
    END;
  END IF;

  IF NOT (_nouveau_statut = ANY(v_next_allowed)) THEN
    RAISE EXCEPTION 'Transition % → % non autorisée pour le mode %', v_current, _nouveau_statut, v_mode;
  END IF;

  v_update_col := CASE _nouveau_statut
    WHEN 'remis_livreur' THEN 'date_remise_livreur'
    WHEN 'en_cours_livraison' THEN 'date_depart'
    WHEN 'arrive_client' THEN 'date_arrivee_client'
    WHEN 'livre' THEN 'date_livraison_reelle'
    WHEN 'depose_gare' THEN 'date_depot_gare'
    WHEN 'en_cours_expedition' THEN 'date_depart'
    WHEN 'arrive_ville' THEN 'date_arrivee_ville'
    WHEN 'remis_client' THEN 'date_remise_client'
    ELSE NULL
  END;

  v_user_nom := COALESCE(auth.jwt()->'user_metadata'->>'nom_complet', auth.jwt()->>'email');

  EXECUTE format(
    'UPDATE public.colis SET statut_logistique=$1, %I=now(), updated_at=now() WHERE colis_id=$2',
    v_update_col
  ) USING _nouveau_statut, _colis_id;

  INSERT INTO public.colis_statut_historique(colis_id, mode_acheminement, ancien_statut, nouveau_statut, commentaire, user_id, user_nom)
  VALUES (_colis_id, v_mode, v_current, _nouveau_statut, _commentaire, auth.uid(), v_user_nom);

  -- Propagation BL
  IF _nouveau_statut IN ('livre','remis_client') AND c.bl_id IS NOT NULL THEN
    v_bl_status := CASE WHEN v_mode='expedition' THEN 'expedie' ELSE 'livre' END;
    -- Marque le BL seulement si TOUS les colis du BL sont finalisés
    IF NOT EXISTS (
      SELECT 1 FROM public.colis
       WHERE bl_id = c.bl_id
         AND colis_id <> _colis_id
         AND statut_logistique NOT IN ('livre','remis_client')
    ) THEN
      UPDATE public.bons_livraison
         SET statut = v_bl_status, updated_at = now()
       WHERE bl_id = c.bl_id;
    END IF;
  END IF;

  SELECT * INTO c FROM public.colis WHERE colis_id = _colis_id;
  RETURN c;
END $$;
