
-- ============================================================
-- Phase 4 : Règles automatiques de détection d'alertes de sécurité
-- ============================================================

CREATE OR REPLACE FUNCTION public.detect_security_alerts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
  v_known integer;
BEGIN
  -- 1) Échecs de connexion répétés (>= 5 en 10 min)
  IF NEW.action IN ('login_failed', 'auth.failed', 'sign_in_failed')
     OR (NEW.action = 'login' AND COALESCE(NEW.status, '') = 'error')
  THEN
    SELECT COUNT(*) INTO v_count
    FROM public.audit_events
    WHERE user_email = NEW.user_email
      AND occurred_at > now() - interval '10 minutes'
      AND (action IN ('login_failed', 'auth.failed', 'sign_in_failed')
           OR (action = 'login' AND COALESCE(status,'') = 'error'));

    IF v_count >= 5 THEN
      INSERT INTO public.security_alerts
        (alert_type, criticite, message, user_id, user_email, ip_address, metadata)
      VALUES (
        'brute_force',
        'critical',
        format('%s tentatives de connexion échouées en 10 minutes', v_count),
        NEW.user_id, NEW.user_email, NEW.ip_address,
        jsonb_build_object('count', v_count, 'window', '10min')
      );
    END IF;
  END IF;

  -- 2) Nouvelle IP jamais utilisée par cet utilisateur (connexions réussies)
  IF NEW.action IN ('login', 'sign_in') AND COALESCE(NEW.status,'') <> 'error'
     AND NEW.user_email IS NOT NULL AND NEW.ip_address IS NOT NULL
  THEN
    SELECT COUNT(*) INTO v_known
    FROM public.audit_events
    WHERE user_email = NEW.user_email
      AND ip_address = NEW.ip_address
      AND id <> NEW.id
      AND occurred_at < NEW.occurred_at;

    IF v_known = 0 THEN
      INSERT INTO public.security_alerts
        (alert_type, criticite, message, user_id, user_email, ip_address, city, country, metadata)
      VALUES (
        'new_ip',
        'warning',
        format('Connexion depuis une nouvelle adresse IP : %s', NEW.ip_address),
        NEW.user_id, NEW.user_email, NEW.ip_address, NEW.city, NEW.country,
        jsonb_build_object('ip', NEW.ip_address)
      );
    END IF;
  END IF;

  -- 3) Suppression massive : >= 10 DELETE en 5 min par le même user
  IF NEW.action = 'delete' THEN
    SELECT COUNT(*) INTO v_count
    FROM public.audit_events
    WHERE user_id = NEW.user_id
      AND action = 'delete'
      AND occurred_at > now() - interval '5 minutes';

    IF v_count >= 10 THEN
      INSERT INTO public.security_alerts
        (alert_type, criticite, message, user_id, user_email, ip_address, metadata)
      VALUES (
        'bulk_delete',
        'critical',
        format('%s suppressions effectuées en 5 minutes', v_count),
        NEW.user_id, NEW.user_email, NEW.ip_address,
        jsonb_build_object('count', v_count, 'table', NEW.table_name)
      );
    END IF;
  END IF;

  -- 4) Changement de rôle / permission
  IF NEW.table_name IN ('user_roles','rbac_user_roles','rbac_role_permissions','rbac_roles')
     AND NEW.action IN ('insert','update','delete')
  THEN
    INSERT INTO public.security_alerts
      (alert_type, criticite, message, user_id, user_email, ip_address, metadata)
    VALUES (
      'permission_change',
      'warning',
      format('Modification de rôles / permissions (%s sur %s)', NEW.action, NEW.table_name),
      NEW.user_id, NEW.user_email, NEW.ip_address,
      jsonb_build_object('table', NEW.table_name, 'record', NEW.record_id)
    );
  END IF;

  -- 5) Export massif
  IF NEW.action IN ('export','export_csv','export_pdf','export_excel') THEN
    INSERT INTO public.security_alerts
      (alert_type, criticite, message, user_id, user_email, ip_address, metadata)
    VALUES (
      'export',
      'info',
      format('Export de données (%s) sur %s', NEW.action, COALESCE(NEW.module, NEW.table_name)),
      NEW.user_id, NEW.user_email, NEW.ip_address,
      jsonb_build_object('module', NEW.module, 'table', NEW.table_name)
    );
  END IF;

  -- 6) Erreur système critique
  IF COALESCE(NEW.status,'') = 'error' AND COALESCE(NEW.criticite::text,'') = 'critical' THEN
    INSERT INTO public.security_alerts
      (alert_type, criticite, message, user_id, user_email, ip_address, metadata)
    VALUES (
      'system_error',
      'critical',
      format('Erreur critique sur %s / %s', NEW.module, NEW.action),
      NEW.user_id, NEW.user_email, NEW.ip_address,
      jsonb_build_object('module', NEW.module, 'action', NEW.action)
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Ne jamais faire échouer l'insertion d'un audit event
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_detect_security_alerts ON public.audit_events;
CREATE TRIGGER trg_detect_security_alerts
AFTER INSERT ON public.audit_events
FOR EACH ROW EXECUTE FUNCTION public.detect_security_alerts();

-- Index utiles pour les détections
CREATE INDEX IF NOT EXISTS idx_audit_events_user_action_time
  ON public.audit_events (user_email, action, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_user_ip
  ON public.audit_events (user_email, ip_address);
