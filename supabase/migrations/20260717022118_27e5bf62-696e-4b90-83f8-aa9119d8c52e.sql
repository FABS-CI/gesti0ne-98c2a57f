CREATE OR REPLACE FUNCTION public.prepare_commande_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.exercice_id IS NULL THEN
    NEW.exercice_id := public._resolve_exercice_id(COALESCE(NEW.date_commande, CURRENT_DATE));

    IF NEW.exercice_id IS NULL THEN
      SELECT e.exercice_id
      INTO NEW.exercice_id
      FROM public.exercices_comptables e
      WHERE e.is_actif IS TRUE OR e.statut = 'actif'
      ORDER BY e.is_actif DESC, e.date_debut DESC
      LIMIT 1;
    END IF;
  END IF;

  IF NEW.client_nom IS NULL OR btrim(NEW.client_nom) = '' THEN
    SELECT c.nom
    INTO NEW.client_nom
    FROM public.clients c
    WHERE c.client_id = NEW.client_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prepare_commande_before_insert ON public.commandes;
CREATE TRIGGER prepare_commande_before_insert
BEFORE INSERT ON public.commandes
FOR EACH ROW
EXECUTE FUNCTION public.prepare_commande_insert();

CREATE OR REPLACE FUNCTION public.notify_commande_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := COALESCE(NEW.created_by, auth.uid());
BEGIN
  IF v_user_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      titre,
      message,
      type_notification,
      priorite,
      module,
      lien,
      document_type,
      document_id,
      document_reference,
      user_id,
      lu,
      date_notification
    ) VALUES (
      'Commande créée — ' || NEW.reference,
      CASE
        WHEN NEW.client_nom IS NOT NULL AND btrim(NEW.client_nom) <> ''
          THEN 'La commande de ' || NEW.client_nom || ' a été enregistrée.'
        ELSE 'La commande a été enregistrée.'
      END,
      'succes',
      'normale',
      'commandes',
      '/commandes/' || NEW.commande_id::text,
      'commande',
      NEW.commande_id::text,
      NEW.reference,
      v_user_id,
      false,
      CURRENT_DATE
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_commande_after_insert ON public.commandes;
CREATE TRIGGER notify_commande_after_insert
AFTER INSERT ON public.commandes
FOR EACH ROW
EXECUTE FUNCTION public.notify_commande_created();

UPDATE public.commandes c
SET exercice_id = COALESCE(
  public._resolve_exercice_id(COALESCE(c.date_commande, CURRENT_DATE)),
  (
    SELECT e.exercice_id
    FROM public.exercices_comptables e
    WHERE e.is_actif IS TRUE OR e.statut = 'actif'
    ORDER BY e.is_actif DESC, e.date_debut DESC
    LIMIT 1
  )
)
WHERE c.exercice_id IS NULL;

UPDATE public.commandes cmd
SET client_nom = cli.nom
FROM public.clients cli
WHERE cmd.client_id = cli.client_id
  AND (cmd.client_nom IS NULL OR btrim(cmd.client_nom) = '');

INSERT INTO public.notifications (
  titre,
  message,
  type_notification,
  priorite,
  module,
  lien,
  document_type,
  document_id,
  document_reference,
  user_id,
  lu,
  date_notification
)
SELECT
  'Commande créée — ' || c.reference,
  CASE
    WHEN c.client_nom IS NOT NULL AND btrim(c.client_nom) <> ''
      THEN 'La commande de ' || c.client_nom || ' a été enregistrée.'
    ELSE 'La commande a été enregistrée.'
  END,
  'succes',
  'normale',
  'commandes',
  '/commandes/' || c.commande_id::text,
  'commande',
  c.commande_id::text,
  c.reference,
  c.created_by,
  false,
  COALESCE(c.date_commande, CURRENT_DATE)
FROM public.commandes c
WHERE c.created_by IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.document_type = 'commande'
      AND n.document_id = c.commande_id::text
      AND n.user_id = c.created_by
  );