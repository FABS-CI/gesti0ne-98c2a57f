DROP POLICY IF EXISTS "transactions write auth" ON public.transactions;

CREATE POLICY "transactions write auth"
ON public.transactions
FOR ALL
TO authenticated
USING (auth.uid() IS NOT NULL)
WITH CHECK (auth.uid() IS NOT NULL);

NOTIFY pgrst, 'reload schema';