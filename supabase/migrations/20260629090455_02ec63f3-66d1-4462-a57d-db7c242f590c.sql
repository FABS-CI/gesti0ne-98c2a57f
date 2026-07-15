
-- 1) Harden is_staff to require an actual staff role, not just any row
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id
      AND role = ANY (ARRAY[
        'super_admin','directeur_general','comptable','directeur_commercial',
        'gestionnaire_stock','responsable_magasinier','secretariat',
        'assistante','service_logistique'
      ]::app_role[])
  )
$$;

-- 2) clients
DROP POLICY IF EXISTS "Clients readable by authenticated" ON public.clients;
DROP POLICY IF EXISTS "Clients insert by authenticated" ON public.clients;
DROP POLICY IF EXISTS "Clients update by authenticated" ON public.clients;
DROP POLICY IF EXISTS "Clients delete by authenticated" ON public.clients;
CREATE POLICY "Staff view clients"   ON public.clients FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert clients" ON public.clients FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update clients" ON public.clients FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete clients" ON public.clients FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 3) employes
DROP POLICY IF EXISTS "Staff view employes"   ON public.employes;
DROP POLICY IF EXISTS "Staff insert employes" ON public.employes;
DROP POLICY IF EXISTS "Staff update employes" ON public.employes;
DROP POLICY IF EXISTS "Staff delete employes" ON public.employes;
CREATE POLICY "Staff view employes"   ON public.employes FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert employes" ON public.employes FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update employes" ON public.employes FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete employes" ON public.employes FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 4) transactions
DROP POLICY IF EXISTS "Staff can view transactions"   ON public.transactions;
DROP POLICY IF EXISTS "Staff can insert transactions" ON public.transactions;
DROP POLICY IF EXISTS "Staff can update transactions" ON public.transactions;
DROP POLICY IF EXISTS "Staff can delete transactions" ON public.transactions;
CREATE POLICY "Staff view transactions"   ON public.transactions FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert transactions" ON public.transactions FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update transactions" ON public.transactions FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete transactions" ON public.transactions FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 5) commandes
DROP POLICY IF EXISTS "Staff can view commandes"   ON public.commandes;
DROP POLICY IF EXISTS "Staff can insert commandes" ON public.commandes;
DROP POLICY IF EXISTS "Staff can update commandes" ON public.commandes;
DROP POLICY IF EXISTS "Staff can delete commandes" ON public.commandes;
CREATE POLICY "Staff view commandes"   ON public.commandes FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert commandes" ON public.commandes FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update commandes" ON public.commandes FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete commandes" ON public.commandes FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 6) commande_lignes
DROP POLICY IF EXISTS "Staff can view lignes"   ON public.commande_lignes;
DROP POLICY IF EXISTS "Staff can insert lignes" ON public.commande_lignes;
DROP POLICY IF EXISTS "Staff can update lignes" ON public.commande_lignes;
DROP POLICY IF EXISTS "Staff can delete lignes" ON public.commande_lignes;
CREATE POLICY "Staff view lignes"   ON public.commande_lignes FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert lignes" ON public.commande_lignes FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update lignes" ON public.commande_lignes FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete lignes" ON public.commande_lignes FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 7) produits
DROP POLICY IF EXISTS "Staff can view produits"   ON public.produits;
DROP POLICY IF EXISTS "Staff can insert produits" ON public.produits;
DROP POLICY IF EXISTS "Staff can update produits" ON public.produits;
DROP POLICY IF EXISTS "Staff can delete produits" ON public.produits;
CREATE POLICY "Staff view produits"   ON public.produits FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert produits" ON public.produits FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update produits" ON public.produits FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete produits" ON public.produits FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 8) achats
DROP POLICY IF EXISTS "Staff view achats"   ON public.achats;
DROP POLICY IF EXISTS "Staff insert achats" ON public.achats;
DROP POLICY IF EXISTS "Staff update achats" ON public.achats;
DROP POLICY IF EXISTS "Staff delete achats" ON public.achats;
CREATE POLICY "Staff view achats"   ON public.achats FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert achats" ON public.achats FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update achats" ON public.achats FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete achats" ON public.achats FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 9) fournisseurs
DROP POLICY IF EXISTS "Staff view fournisseurs"   ON public.fournisseurs;
DROP POLICY IF EXISTS "Staff insert fournisseurs" ON public.fournisseurs;
DROP POLICY IF EXISTS "Staff update fournisseurs" ON public.fournisseurs;
DROP POLICY IF EXISTS "Staff delete fournisseurs" ON public.fournisseurs;
CREATE POLICY "Staff view fournisseurs"   ON public.fournisseurs FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert fournisseurs" ON public.fournisseurs FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update fournisseurs" ON public.fournisseurs FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete fournisseurs" ON public.fournisseurs FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 10) conges
DROP POLICY IF EXISTS "Staff view conges"   ON public.conges;
DROP POLICY IF EXISTS "Staff insert conges" ON public.conges;
DROP POLICY IF EXISTS "Staff update conges" ON public.conges;
DROP POLICY IF EXISTS "Staff delete conges" ON public.conges;
CREATE POLICY "Staff view conges"   ON public.conges FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "Staff insert conges" ON public.conges FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff update conges" ON public.conges FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE POLICY "Staff delete conges" ON public.conges FOR DELETE TO authenticated USING (public.is_staff(auth.uid()));

-- 11) profiles : own row, staff voit tout
DROP POLICY IF EXISTS "Profiles readable by authenticated" ON public.profiles;
CREATE POLICY "Users view own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id OR public.is_staff(auth.uid()));
