-- Table des responsables de colisage
CREATE TABLE public.colisage_responsables (
  responsable_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employe_id uuid NOT NULL UNIQUE REFERENCES public.employes(employe_id) ON DELETE RESTRICT,
  depot_id uuid REFERENCES public.depots(depot_id) ON DELETE SET NULL,
  actif boolean NOT NULL DEFAULT true,
  date_affectation timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON public.colisage_responsables TO authenticated;
GRANT ALL ON public.colisage_responsables TO service_role;

ALTER TABLE public.colisage_responsables ENABLE ROW LEVEL SECURITY;

-- Lecture: tout authenticated (pour alimenter le Select du formulaire)
CREATE POLICY "colisage_resp read" ON public.colisage_responsables
  FOR SELECT TO authenticated USING (true);

-- Ecriture: uniquement rôles autorisés
CREATE POLICY "colisage_resp insert" ON public.colisage_responsables
  FOR INSERT TO authenticated WITH CHECK (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_role(auth.uid(), 'gestionnaire_stock')
    OR public.has_role(auth.uid(), 'responsable_magasinier')
  );

CREATE POLICY "colisage_resp update" ON public.colisage_responsables
  FOR UPDATE TO authenticated USING (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_role(auth.uid(), 'gestionnaire_stock')
    OR public.has_role(auth.uid(), 'responsable_magasinier')
  ) WITH CHECK (
    public.has_role(auth.uid(), 'super_admin')
    OR public.has_role(auth.uid(), 'gestionnaire_stock')
    OR public.has_role(auth.uid(), 'responsable_magasinier')
  );

-- Pas de policy DELETE => suppression physique interdite

-- Trigger updated_at
CREATE TRIGGER update_colisage_responsables_updated_at
  BEFORE UPDATE ON public.colisage_responsables
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger d'audit
CREATE OR REPLACE FUNCTION public.audit_colisage_responsables()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id, new_values)
    VALUES (auth.uid(), v_email, 'INSERT', 'colisage_responsables', NEW.responsable_id, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.audit_logs (user_id, user_email, action, table_name, record_id, old_values, new_values)
    VALUES (
      auth.uid(), v_email,
      CASE
        WHEN OLD.actif IS DISTINCT FROM NEW.actif THEN
          CASE WHEN NEW.actif THEN 'ACTIVATE' ELSE 'DEACTIVATE' END
        ELSE 'UPDATE'
      END,
      'colisage_responsables', NEW.responsable_id, to_jsonb(OLD), to_jsonb(NEW)
    );
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER audit_colisage_responsables_trg
  AFTER INSERT OR UPDATE ON public.colisage_responsables
  FOR EACH ROW EXECUTE FUNCTION public.audit_colisage_responsables();

-- Vue enrichie avec les infos employé + dépôt
CREATE OR REPLACE VIEW public.v_colisage_responsables
WITH (security_invoker = true)
AS
SELECT
  cr.responsable_id,
  cr.employe_id,
  e.matricule,
  e.nom_complet,
  e.poste,
  e.telephone,
  cr.depot_id,
  d.nom AS depot_nom,
  cr.actif,
  cr.date_affectation,
  cr.created_at,
  cr.updated_at
FROM public.colisage_responsables cr
JOIN public.employes e ON e.employe_id = cr.employe_id
LEFT JOIN public.depots d ON d.depot_id = cr.depot_id;

GRANT SELECT ON public.v_colisage_responsables TO authenticated;