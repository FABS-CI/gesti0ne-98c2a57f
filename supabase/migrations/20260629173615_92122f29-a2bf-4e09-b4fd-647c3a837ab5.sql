
-- Lot 1 : extension de la table depots
ALTER TABLE public.depots
  ADD COLUMN IF NOT EXISTS type_depot text NOT NULL DEFAULT 'secondaire',
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS pays text DEFAULT 'Côte d''Ivoire',
  ADD COLUMN IF NOT EXISTS ville text,
  ADD COLUMN IF NOT EXISTS commune text,
  ADD COLUMN IF NOT EXISTS quartier text,
  ADD COLUMN IF NOT EXISTS code_postal text,
  ADD COLUMN IF NOT EXISTS latitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS longitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS responsable_email text,
  ADD COLUMN IF NOT EXISTS capacite integer;

-- Contrainte sur type_depot (via trigger pour rester non-immutable)
ALTER TABLE public.depots DROP CONSTRAINT IF EXISTS depots_type_depot_chk;
ALTER TABLE public.depots ADD CONSTRAINT depots_type_depot_chk
  CHECK (type_depot IN ('principal','secondaire','temporaire','boutique','autre'));

-- Aligne is_principal/type_depot lorsqu'un dépôt principal existe
UPDATE public.depots SET type_depot = 'principal' WHERE is_principal = true AND type_depot <> 'principal';

-- Audit automatique des dépôts
CREATE OR REPLACE FUNCTION public.audit_depot_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
      VALUES (auth.uid(), 'create_depot', 'depots', NEW.depot_id::text);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
      VALUES (auth.uid(), 'update_depot', 'depots', NEW.depot_id::text);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_logs (user_id, action, table_name, record_id)
      VALUES (auth.uid(), 'delete_depot', 'depots', OLD.depot_id::text);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS depots_audit ON public.depots;
CREATE TRIGGER depots_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.depots
  FOR EACH ROW EXECUTE FUNCTION public.audit_depot_change();
