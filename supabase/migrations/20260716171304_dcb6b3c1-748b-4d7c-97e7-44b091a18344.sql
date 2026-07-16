DROP POLICY IF EXISTS clients_sales_read ON public.clients;

CREATE POLICY clients_authorized_read
ON public.clients
FOR SELECT
TO authenticated
USING (
  public.is_sales(auth.uid())
  OR public.has_any_role(
    auth.uid(),
    ARRAY[
      'gestionnaire_stock',
      'service_logistique',
      'responsable_magasinier'
    ]::public.app_role[]
  )
);