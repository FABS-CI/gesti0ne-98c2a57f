
-- =========================================================================
-- MODULE FIDÉLITÉ CLIENT
-- Barème : 1 pt / 1 000 F payés, expiration 24 mois, 1 pt = 10 F, plafond 20 % HT
-- =========================================================================

-- 1. Colonne dénormalisée sur clients
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS solde_points integer NOT NULL DEFAULT 0;

-- 2. Table des mouvements
CREATE TABLE IF NOT EXISTS public.client_fidelite_mouvements (
  mouvement_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id        uuid NOT NULL REFERENCES public.clients(client_id) ON DELETE CASCADE,
  type             text NOT NULL CHECK (type IN ('gain','utilisation','annulation','expiration','ajustement')),
  points           integer NOT NULL,  -- positif = crédit, négatif = débit
  date_mouvement   timestamptz NOT NULL DEFAULT now(),
  date_expiration  timestamptz,
  paiement_id      uuid REFERENCES public.paiements(paiement_id) ON DELETE SET NULL,
  facture_id       uuid REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  motif            text,
  created_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.client_fidelite_mouvements TO authenticated;
GRANT ALL    ON public.client_fidelite_mouvements TO service_role;

ALTER TABLE public.client_fidelite_mouvements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "staff read fidelite" ON public.client_fidelite_mouvements
  FOR SELECT TO authenticated
  USING (public.is_staff(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_fid_client        ON public.client_fidelite_mouvements(client_id, date_mouvement DESC);
CREATE INDEX IF NOT EXISTS idx_fid_paiement      ON public.client_fidelite_mouvements(paiement_id) WHERE paiement_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fid_expiration    ON public.client_fidelite_mouvements(date_expiration) WHERE type = 'gain';

-- 3. Trigger : maintien du solde dénormalisé
CREATE OR REPLACE FUNCTION public.tg_fidelite_maj_solde()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.clients
     SET solde_points = COALESCE(solde_points,0) + NEW.points,
         updated_at   = now()
   WHERE client_id = NEW.client_id;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_fidelite_maj_solde ON public.client_fidelite_mouvements;
CREATE TRIGGER trg_fidelite_maj_solde
  AFTER INSERT ON public.client_fidelite_mouvements
  FOR EACH ROW EXECUTE FUNCTION public.tg_fidelite_maj_solde();

-- 4. Trigger sur paiements : gain automatique / annulation symétrique
CREATE OR REPLACE FUNCTION public.tg_paiement_fidelite()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_client_id uuid;
  v_points    integer;
BEGIN
  -- Résout le client via la facture liée
  SELECT client_id INTO v_client_id
    FROM public.factures
   WHERE facture_id = COALESCE(NEW.facture_id, OLD.facture_id);
  IF v_client_id IS NULL THEN RETURN NEW; END IF;

  -- INSERT validé => gain
  IF TG_OP = 'INSERT' AND NEW.statut = 'valide' THEN
    v_points := floor(NEW.montant / 1000)::int;
    IF v_points > 0 THEN
      INSERT INTO public.client_fidelite_mouvements
        (client_id, type, points, date_expiration, paiement_id, motif)
      VALUES
        (v_client_id, 'gain', v_points, now() + interval '24 months', NEW.paiement_id,
         'Gain automatique sur paiement ' || NEW.reference);
    END IF;

  -- UPDATE valide -> annule => annulation symétrique
  ELSIF TG_OP = 'UPDATE'
        AND OLD.statut = 'valide' AND NEW.statut <> 'valide' THEN
    SELECT COALESCE(SUM(points),0) INTO v_points
      FROM public.client_fidelite_mouvements
     WHERE paiement_id = NEW.paiement_id AND type = 'gain';
    IF v_points > 0 THEN
      INSERT INTO public.client_fidelite_mouvements
        (client_id, type, points, paiement_id, motif)
      VALUES
        (v_client_id, 'annulation', -v_points, NEW.paiement_id,
         'Annulation paiement ' || NEW.reference);
    END IF;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_paiement_fidelite ON public.paiements;
CREATE TRIGGER trg_paiement_fidelite
  AFTER INSERT OR UPDATE OF statut ON public.paiements
  FOR EACH ROW EXECUTE FUNCTION public.tg_paiement_fidelite();

-- 5. RPC : utilisation des points sur une facture
CREATE OR REPLACE FUNCTION public.utiliser_points_fidelite(
  _facture_id uuid,
  _points     integer
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_client_id   uuid;
  v_montant_ht  numeric;
  v_solde       integer;
  v_max_points  integer;
  v_remise      numeric;
BEGIN
  IF _points IS NULL OR _points <= 0 THEN
    RAISE EXCEPTION 'Nombre de points invalide';
  END IF;

  SELECT client_id, montant_total INTO v_client_id, v_montant_ht
    FROM public.factures WHERE facture_id = _facture_id;
  IF v_client_id IS NULL THEN RAISE EXCEPTION 'Facture introuvable ou sans client'; END IF;

  SELECT COALESCE(solde_points,0) INTO v_solde
    FROM public.clients WHERE client_id = v_client_id FOR UPDATE;

  IF _points > v_solde THEN
    RAISE EXCEPTION 'Solde insuffisant : % points demandés, % disponibles', _points, v_solde;
  END IF;

  -- Plafond 20 % du montant HT (1 pt = 10 F CFA)
  v_max_points := floor((v_montant_ht * 0.20) / 10)::int;
  IF _points > v_max_points THEN
    RAISE EXCEPTION 'Plafond dépassé : max % points (20%% du HT) pour cette facture', v_max_points;
  END IF;

  v_remise := _points * 10;

  INSERT INTO public.client_fidelite_mouvements
    (client_id, type, points, facture_id, motif, created_by)
  VALUES
    (v_client_id, 'utilisation', -_points, _facture_id,
     'Remise fidélité de ' || v_remise || ' F CFA', auth.uid());

  RETURN jsonb_build_object(
    'points_utilises', _points,
    'remise_fcfa',     v_remise,
    'nouveau_solde',   v_solde - _points
  );
END $$;

REVOKE ALL ON FUNCTION public.utiliser_points_fidelite(uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.utiliser_points_fidelite(uuid,integer) TO authenticated;

-- 6. Job d'expiration FIFO (à planifier via pg_cron nocturne)
CREATE OR REPLACE FUNCTION public.expirer_points_fidelite()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r          RECORD;
  v_conso    integer;
  v_expire   integer;
  v_total    integer := 0;
BEGIN
  -- Pour chaque client, on additionne les points expirés (gain avec date_expiration <= now)
  -- moins ce qui a déjà été consommé/annulé/expiré (FIFO simplifié : on regarde les gains périmés
  -- et on soustrait la somme des débits postérieurs à leur émission).
  FOR r IN
    SELECT client_id,
           COALESCE(SUM(points),0) AS points_perimes
      FROM public.client_fidelite_mouvements
     WHERE type = 'gain'
       AND date_expiration <= now()
       AND NOT EXISTS (
         SELECT 1 FROM public.client_fidelite_mouvements e
          WHERE e.client_id = client_fidelite_mouvements.client_id
            AND e.type = 'expiration'
            AND e.motif = 'expiration-lot:' || client_fidelite_mouvements.mouvement_id::text
       )
     GROUP BY client_id
  LOOP
    -- Consommation nette depuis l'origine
    SELECT COALESCE(SUM(-points),0) INTO v_conso
      FROM public.client_fidelite_mouvements
     WHERE client_id = r.client_id
       AND type IN ('utilisation','annulation','expiration');

    v_expire := GREATEST(r.points_perimes - v_conso, 0);
    IF v_expire > 0 THEN
      INSERT INTO public.client_fidelite_mouvements
        (client_id, type, points, motif)
      VALUES
        (r.client_id, 'expiration', -v_expire,
         'Expiration automatique de ' || v_expire || ' point(s) (>24 mois)');
      v_total := v_total + v_expire;
    END IF;
  END LOOP;

  RETURN v_total;
END $$;

REVOKE ALL ON FUNCTION public.expirer_points_fidelite() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expirer_points_fidelite() TO service_role;

-- 7. Planification nocturne (2h du matin)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('expirer-points-fidelite')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expirer-points-fidelite');
    PERFORM cron.schedule('expirer-points-fidelite', '0 2 * * *',
      $c$SELECT public.expirer_points_fidelite();$c$);
  END IF;
END $$;
