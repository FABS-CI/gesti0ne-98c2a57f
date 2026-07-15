-- =========================================================================
-- Unification numérotation documents — format PREFIX-YYYY-NNNNNNNN
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.numerotation_compteurs (
  type_doc text NOT NULL,
  annee    int  NOT NULL,
  dernier_numero bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (type_doc, annee)
);

GRANT SELECT ON public.numerotation_compteurs TO authenticated;
GRANT ALL ON public.numerotation_compteurs TO service_role;
ALTER TABLE public.numerotation_compteurs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "read compteurs" ON public.numerotation_compteurs;
CREATE POLICY "read compteurs" ON public.numerotation_compteurs
  FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public.next_document_number(
  _prefix text,
  _year   int DEFAULT EXTRACT(year FROM now())::int
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_n bigint;
BEGIN
  INSERT INTO public.numerotation_compteurs(type_doc, annee, dernier_numero, updated_at)
  VALUES (_prefix, _year, 1, now())
  ON CONFLICT (type_doc, annee) DO UPDATE
    SET dernier_numero = numerotation_compteurs.dernier_numero + 1,
        updated_at = now()
  RETURNING dernier_numero INTO v_n;
  RETURN _prefix || '-' || _year::text || '-' || lpad(v_n::text, 8, '0');
END;$$;

GRANT EXECUTE ON FUNCTION public.next_document_number(text, int) TO authenticated, service_role;

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;

CREATE OR REPLACE FUNCTION public.tg_set_document_number()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_prefix text := TG_ARGV[0];
  v_col    text := TG_ARGV[1];
  v_val    text;
  v_year   int;
BEGIN
  EXECUTE format('SELECT ($1).%I::text', v_col) INTO v_val USING NEW;
  IF v_val IS NULL OR v_val !~ '^[A-Z]{2,3}-[0-9]{4}-[0-9]{8}$' THEN
    v_year := EXTRACT(year FROM COALESCE(
      (row_to_json(NEW)->>'created_at')::timestamptz, now()))::int;
    v_val := public.next_document_number(v_prefix, v_year);
    NEW := NEW #= hstore(v_col, v_val);
  END IF;
  RETURN NEW;
END;$$;

-- Installation triggers + suppression anciens défauts
DO $$
DECLARE
  m text[][] := ARRAY[
    ['commandes',       'reference', 'CMD'],
    ['proformas',       'reference', 'PF'],
    ['bons_livraison',  'reference', 'BL'],
    ['livraisons',      'reference', 'LV'],
    ['factures',        'reference', 'FA'],
    ['fne_factures',    'reference', 'FN'],
    ['avoirs',          'reference', 'AV'],
    ['bons_retour',     'reference', 'BR'],
    ['retours',         'reference', 'RET'],
    ['achats',          'reference', 'ACH'],
    ['paiements',       'reference', 'PMT'],
    ['tournees',        'reference', 'TRN'],
    ['inventaires',     'reference', 'INV'],
    ['transferts',      'numero',    'TR'],
    ['incidents',       'reference', 'INC'],
    ['specimens',       'reference', 'SPE'],
    ['expeditions',     'reference', 'EXP'],
    ['ordres_colisage', 'reference', 'OC'],
    ['missions',        'reference', 'MIS']
  ];
  i int; tbl text; col text; prefix text;
BEGIN
  FOR i IN 1..array_length(m,1) LOOP
    tbl := m[i][1]; col := m[i][2]; prefix := m[i][3];
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I DROP DEFAULT', tbl, col);
    BEGIN EXECUTE format('ALTER TABLE public.%I ALTER COLUMN %I DROP NOT NULL', tbl, col);
    EXCEPTION WHEN others THEN NULL; END;
    EXECUTE format('DROP TRIGGER IF EXISTS trg_set_%I_%I ON public.%I', tbl, col, tbl);
    EXECUTE format(
      'CREATE TRIGGER trg_set_%I_%I BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.tg_set_document_number(%L, %L)',
      tbl, col, tbl, prefix, col);
  END LOOP;
END$$;

-- Renumérotation des données existantes (test) — PK réelles
DO $$
DECLARE
  m text[][] := ARRAY[
    ['commandes',       'reference', 'commande_id',  'CMD'],
    ['proformas',       'reference', 'proforma_id',  'PF'],
    ['bons_livraison',  'reference', 'bl_id',        'BL'],
    ['livraisons',      'reference', 'livraison_id', 'LV'],
    ['factures',        'reference', 'facture_id',   'FA'],
    ['fne_factures',    'reference', 'fne_id',       'FN'],
    ['avoirs',          'reference', 'avoir_id',     'AV'],
    ['bons_retour',     'reference', 'br_id',        'BR'],
    ['retours',         'reference', 'retour_id',    'RET'],
    ['achats',          'reference', 'achat_id',     'ACH'],
    ['paiements',       'reference', 'paiement_id',  'PMT'],
    ['tournees',        'reference', 'tournee_id',   'TRN'],
    ['inventaires',     'reference', 'inventaire_id','INV'],
    ['transferts',      'numero',    'transfert_id', 'TR'],
    ['incidents',       'reference', 'incident_id',  'INC'],
    ['specimens',       'reference', 'specimen_id',  'SPE'],
    ['expeditions',     'reference', 'expedition_id','EXP'],
    ['ordres_colisage', 'reference', 'ordre_id',     'OC'],
    ['missions',        'reference', 'mission_id',   'MIS']
  ];
  i int; tbl text; col text; pk text; prefix text; q text;
BEGIN
  FOR i IN 1..array_length(m,1) LOOP
    tbl := m[i][1]; col := m[i][2]; pk := m[i][3]; prefix := m[i][4];
    DELETE FROM public.numerotation_compteurs WHERE type_doc = prefix;

    q := format($f$
      WITH ordered AS (
        SELECT %I AS pk_val, created_at,
               EXTRACT(year FROM created_at)::int AS yr,
               ROW_NUMBER() OVER (PARTITION BY EXTRACT(year FROM created_at) ORDER BY created_at, %I) AS rn
          FROM public.%I
      )
      UPDATE public.%I t
         SET %I = %L || '-' || o.yr::text || '-' || lpad(o.rn::text, 8, '0')
        FROM ordered o
       WHERE t.%I = o.pk_val
    $f$, pk, pk, tbl, tbl, col, prefix, pk);
    EXECUTE q;

    EXECUTE format($f$
      INSERT INTO public.numerotation_compteurs(type_doc, annee, dernier_numero, updated_at)
      SELECT %L, EXTRACT(year FROM created_at)::int, COUNT(*), now()
        FROM public.%I
       WHERE %I IS NOT NULL
       GROUP BY EXTRACT(year FROM created_at)
      ON CONFLICT (type_doc, annee) DO UPDATE
        SET dernier_numero = EXCLUDED.dernier_numero, updated_at = now()
    $f$, prefix, tbl, col);
  END LOOP;
END$$;

-- Contraintes CHECK
DO $$
DECLARE
  m text[][] := ARRAY[
    ['commandes','reference'],['proformas','reference'],['bons_livraison','reference'],
    ['livraisons','reference'],['factures','reference'],['fne_factures','reference'],
    ['avoirs','reference'],['bons_retour','reference'],['retours','reference'],
    ['achats','reference'],['paiements','reference'],['tournees','reference'],
    ['inventaires','reference'],['transferts','numero'],['incidents','reference'],
    ['specimens','reference'],['expeditions','reference'],['ordres_colisage','reference'],
    ['missions','reference']
  ];
  i int; tbl text; col text; cname text;
BEGIN
  FOR i IN 1..array_length(m,1) LOOP
    tbl := m[i][1]; col := m[i][2];
    cname := 'chk_' || tbl || '_' || col || '_format';
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', tbl, cname);
    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (%I IS NULL OR %I ~ ''^[A-Z]{2,3}-[0-9]{4}-[0-9]{8}$'') NOT VALID',
      tbl, cname, col, col);
    BEGIN EXECUTE format('ALTER TABLE public.%I VALIDATE CONSTRAINT %I', tbl, cname);
    EXCEPTION WHEN check_violation THEN
      RAISE NOTICE 'CHECK non validée pour %.%', tbl, col;
    END;
  END LOOP;
END$$;

DROP TRIGGER IF EXISTS trg_specimens_reference ON public.specimens;
DROP FUNCTION IF EXISTS public.set_specimen_reference() CASCADE;
