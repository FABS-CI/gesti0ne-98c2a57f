CREATE OR REPLACE FUNCTION public.produit_niveau_ordre(n text)
RETURNS int
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN n IS NULL OR n = '' THEN 9999
    WHEN n ILIKE '%petite section%' OR n ~* '(^|[^a-z])ps([^a-z]|$)' THEN 10
    WHEN n ILIKE '%moyenne section%' OR n ~* '(^|[^a-z])ms([^a-z]|$)' THEN 20
    WHEN n ILIKE '%grande section%'  OR n ~* '(^|[^a-z])gs([^a-z]|$)' THEN 30
    WHEN n ~* '(^|[^a-z])cp\s*1([^a-z0-9]|$)' OR n ~* 'cp1' THEN 40
    WHEN n ~* '(^|[^a-z])cp\s*2([^a-z0-9]|$)' OR n ~* 'cp2' THEN 50
    WHEN n ~* 'ce\s*1' THEN 60
    WHEN n ~* 'ce\s*2' THEN 70
    WHEN n ~* 'cm\s*1' THEN 80
    WHEN n ~* 'cm\s*2' THEN 90
    WHEN n ~* '(^|[^0-9])6\s*[èe]me' OR n ~* '(^|[^a-z])6e([^a-z]|$)' THEN 100
    WHEN n ~* '(^|[^0-9])5\s*[èe]me' OR n ~* '(^|[^a-z])5e([^a-z]|$)' THEN 110
    WHEN n ~* '(^|[^0-9])4\s*[èe]me' OR n ~* '(^|[^a-z])4e([^a-z]|$)' THEN 120
    WHEN n ~* '(^|[^0-9])3\s*[èe]me' OR n ~* '(^|[^a-z])3e([^a-z]|$)' THEN 130
    WHEN n ILIKE '%seconde%' OR n ~* '(^|[^a-z])2nde([^a-z]|$)' THEN 140
    WHEN n ILIKE '%premi%re%'  OR n ~* '(^|[^a-z])1[èe]re([^a-z]|$)' THEN 150
    WHEN n ILIKE '%terminale%' OR n ~* '(^|[^a-z])(tle|term)([^a-z]|$)' THEN 160
    ELSE 9999
  END
$$;