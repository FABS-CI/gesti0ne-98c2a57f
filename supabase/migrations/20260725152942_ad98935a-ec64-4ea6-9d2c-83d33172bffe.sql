
-- ============================================================
-- Lot A : Notifications d'approbation + SLA temps réel
-- ============================================================

-- 1) Fonction de notification aux approbateurs éligibles
CREATE OR REPLACE FUNCTION public.notifier_approbateurs_workflow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_titre TEXT;
  v_message TEXT;
  v_priorite TEXT;
  v_lien TEXT;
BEGIN
  -- N'agit qu'à la création d'une demande "en_attente"
  IF NEW.statut IS DISTINCT FROM 'en_attente' THEN
    RETURN NEW;
  END IF;

  v_titre := CASE NEW.module
    WHEN 'retours' THEN '↩️ Retour à valider'
    WHEN 'paiements' THEN '💰 Paiement à approuver'
    WHEN 'logistique' THEN '🚚 Frais logistiques à valider'
    WHEN 'commandes' THEN '⚠️ Annulation commande'
    ELSE '📋 Nouvelle approbation'
  END;

  v_message := format('%s • Demandé par %s • %s',
    COALESCE(NEW.reference, 'Réf. N/A'),
    COALESCE(NEW.demandeur_nom, 'Utilisateur'),
    CASE NEW.niveau_urgence
      WHEN 'critique' THEN '🔴 Critique'
      WHEN 'haute' THEN '🟠 Haute'
      WHEN 'normale' THEN '🟡 Normale'
      ELSE '🟢 Basse'
    END
  );

  v_priorite := CASE NEW.niveau_urgence
    WHEN 'critique' THEN 'urgente'
    WHEN 'haute' THEN 'haute'
    ELSE 'normale'
  END;

  v_lien := CASE NEW.module
    WHEN 'retours' THEN '/retours/' || COALESCE(NEW.entity_id::text, '')
    ELSE '/approbations'
  END;

  -- Notifier chaque utilisateur ayant la permission approbations.valider
  FOR v_user_id IN
    SELECT DISTINCT ur.user_id
    FROM public.rbac2_user_roles ur
    JOIN public.rbac2_role_perms rp ON rp.role_id = ur.role_id
    JOIN public.rbac2_permissions p ON p.id = rp.perm_id
    WHERE p.code IN ('approbations.valider', 'approbations.*', '*')
      AND ur.user_id IS DISTINCT FROM NEW.demandeur_id
  LOOP
    INSERT INTO public.notifications (
      user_id, titre, message, type_notification, priorite,
      module, lien, document_type, document_id, document_reference
    ) VALUES (
      v_user_id, v_titre, v_message, 'approbation', v_priorite,
      'approbations', v_lien, 'workflow_approval', NEW.id::text, NEW.reference
    );
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Ne jamais bloquer la création de l'approbation si notif échoue
  RAISE WARNING 'notifier_approbateurs_workflow: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifier_approbateurs ON public.workflow_approvals;
CREATE TRIGGER trg_notifier_approbateurs
AFTER INSERT ON public.workflow_approvals
FOR EACH ROW EXECUTE FUNCTION public.notifier_approbateurs_workflow();

-- 2) Recalcul SLA : passe à critique si deadline dépassée
CREATE OR REPLACE FUNCTION public.recalculer_sla_approbations()
RETURNS TABLE(mis_a_jour INT, notifies INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_maj INT := 0;
  v_notif INT := 0;
  v_row RECORD;
BEGIN
  -- Passer à critique tout ce qui a dépassé le SLA
  UPDATE public.workflow_approvals
  SET niveau_urgence = 'critique',
      updated_at = now()
  WHERE statut = 'en_attente'
    AND sla_deadline IS NOT NULL
    AND sla_deadline < now()
    AND niveau_urgence IS DISTINCT FROM 'critique';

  GET DIAGNOSTICS v_maj = ROW_COUNT;

  -- Notifier les retards SLA (une seule fois via metadata->>'sla_alert_sent')
  FOR v_row IN
    SELECT id, reference, module, entity_id, demandeur_id
    FROM public.workflow_approvals
    WHERE statut = 'en_attente'
      AND sla_deadline < now()
      AND COALESCE((metadata->>'sla_alert_sent')::boolean, false) = false
  LOOP
    INSERT INTO public.notifications (
      user_id, titre, message, type_notification, priorite,
      module, lien, document_type, document_id, document_reference
    )
    SELECT DISTINCT ur.user_id,
      '⏰ SLA dépassé — Action urgente',
      format('Approbation %s en retard depuis %s',
        v_row.reference,
        age(now(), (SELECT sla_deadline FROM public.workflow_approvals WHERE id = v_row.id))::text
      ),
      'sla_warning', 'urgente', 'approbations',
      CASE v_row.module WHEN 'retours' THEN '/retours/' || v_row.entity_id::text ELSE '/approbations' END,
      'workflow_approval', v_row.id::text, v_row.reference
    FROM public.rbac2_user_roles ur
    JOIN public.rbac2_role_perms rp ON rp.role_id = ur.role_id
    JOIN public.rbac2_permissions p ON p.id = rp.perm_id
    WHERE p.code IN ('approbations.valider', 'approbations.*', '*');

    UPDATE public.workflow_approvals
    SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('sla_alert_sent', true)
    WHERE id = v_row.id;

    v_notif := v_notif + 1;
  END LOOP;

  RETURN QUERY SELECT v_maj, v_notif;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recalculer_sla_approbations() TO authenticated, service_role;

-- 3) Vue pour le badge sidebar (compteur en attente global)
CREATE OR REPLACE VIEW public.v_approbations_en_attente_count AS
SELECT
  COUNT(*)::int AS total,
  COUNT(*) FILTER (WHERE niveau_urgence = 'critique')::int AS critiques,
  COUNT(*) FILTER (WHERE sla_deadline < now())::int AS sla_depasses
FROM public.workflow_approvals
WHERE statut = 'en_attente';

GRANT SELECT ON public.v_approbations_en_attente_count TO authenticated;

-- 4) Job pg_cron toutes les 15 min
DO $$
BEGIN
  -- Supprime l'ancien job s'il existe
  PERFORM cron.unschedule('recalculer-sla-approbations');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'recalculer-sla-approbations',
  '*/15 * * * *',
  $$ SELECT public.recalculer_sla_approbations(); $$
);
