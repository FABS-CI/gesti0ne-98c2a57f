
-- 1. Nouvelles colonnes couverture
ALTER TABLE public.produits
  ADD COLUMN IF NOT EXISTS cover_path text,
  ADD COLUMN IF NOT EXISTS cover_thumb_path text,
  ADD COLUMN IF NOT EXISTS cover_updated_at timestamptz;

-- 2. Recréer la vue v_produits en exposant les nouvelles colonnes
DROP VIEW IF EXISTS public.v_produits;
CREATE VIEW public.v_produits
WITH (security_invoker = on)
AS
SELECT
  produit_id, reference, titre, isbn, categorie, categorie_id, niveau, niveau_ordre,
  matiere, auteur, editeur, prix_vente, prix_achat,
  COALESCE((SELECT sum(sd.quantite)::integer
              FROM stocks_depots sd
             WHERE sd.produit_id = p.produit_id), 0) AS stock,
  seuil_alerte, actif, created_at, updated_at,
  cover_path, cover_thumb_path, cover_updated_at,
  CASE WHEN produit_id = 'f8572bf4-4da3-430f-874f-98972a1f9d17'::uuid THEN 0 ELSE 1 END AS pin_order
FROM public.produits p;

GRANT SELECT ON public.v_produits TO authenticated;

-- 3. Storage policies sur le bucket product-covers
DROP POLICY IF EXISTS "product-covers: read auth" ON storage.objects;
CREATE POLICY "product-covers: read auth" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'product-covers');

DROP POLICY IF EXISTS "product-covers: insert produits.modifier" ON storage.objects;
CREATE POLICY "product-covers: insert produits.modifier" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'product-covers'
    AND public.has_permission_v2(auth.uid(), 'produits.modifier')
  );

DROP POLICY IF EXISTS "product-covers: update produits.modifier" ON storage.objects;
CREATE POLICY "product-covers: update produits.modifier" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'product-covers'
    AND public.has_permission_v2(auth.uid(), 'produits.modifier')
  )
  WITH CHECK (
    bucket_id = 'product-covers'
    AND public.has_permission_v2(auth.uid(), 'produits.modifier')
  );

DROP POLICY IF EXISTS "product-covers: delete produits.modifier" ON storage.objects;
CREATE POLICY "product-covers: delete produits.modifier" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'product-covers'
    AND public.has_permission_v2(auth.uid(), 'produits.modifier')
  );
