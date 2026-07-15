-- 1) Security Definer View : v_produits doit s'exécuter avec les droits de l'utilisateur.
ALTER VIEW public.v_produits SET (security_invoker = on);

-- 2) Retirer l'exposition PII : plus de self-read RLS sur employes.
DROP POLICY IF EXISTS "employe read own record" ON public.employes;