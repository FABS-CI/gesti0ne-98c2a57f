
-- Fix the remaining true INSERT policy on stock_mouvements
DROP POLICY IF EXISTS "Staff can insert mouvements" ON public.stock_mouvements;
DROP POLICY IF EXISTS "Staff can view mouvements"   ON public.stock_mouvements;
CREATE POLICY "Staff view mouvements"   ON public.stock_mouvements FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert mouvements" ON public.stock_mouvements FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));

-- Lock down SECURITY DEFINER functions: remove direct EXECUTE for client roles.
-- They remain callable from RLS policies (run as owner) and from service_role.
REVOKE EXECUTE ON FUNCTION public.is_staff(uuid)                          FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role)                FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.has_any_role(uuid, app_role[])          FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.bootstrap_first_super_admin()           FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()                       FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.apply_stock_mouvement()                 FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.executer_transfert(uuid)                FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.receptionner_transfert(uuid)            FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.annuler_transfert(uuid)                 FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column()              FROM anon, authenticated, public;

-- Transfert helpers must stay callable by signed-in staff via PostgREST RPC
GRANT EXECUTE ON FUNCTION public.executer_transfert(uuid)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.receptionner_transfert(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.annuler_transfert(uuid)      TO authenticated;
