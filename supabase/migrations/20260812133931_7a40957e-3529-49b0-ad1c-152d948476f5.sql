-- GESTI-ONE 2.0.3 — Alignement search_clients_crm avec pg_trgm
CREATE OR REPLACE FUNCTION public.search_clients_crm(
    _filters jsonb DEFAULT '{}'::jsonb, 
    _limit integer DEFAULT 50, 
    _offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql 
STABLE 
SECURITY DEFINER 
SET search_path = public
AS $$
DECLARE 
    v_q text := _filters->>'q'; 
    v_q_norm text;
    v_total bigint; 
    v_items jsonb;
    v_type text := _filters->>'type_client';
    v_ville text := _filters->>'ville';
    v_actif boolean := (_filters->>'actif')::boolean;
BEGIN
    PERFORM public.assert_permission('clients.voir');
    
    IF v_q IS NOT NULL THEN
        v_q_norm := public.normalize_phone(v_q);
    END IF;

    WITH base_search AS (
        SELECT c.*
        FROM public.clients c
        WHERE (
            v_q IS NULL 
            OR c.nom ILIKE '%'||v_q||'%' 
            OR c.reference ILIKE '%'||v_q||'%'
            OR c.ville ILIKE '%'||v_q||'%'
            OR (v_q_norm IS NOT NULL AND v_q_norm <> '' AND (
                   c.phone_normalized LIKE '%'||v_q_norm||'%' 
            ))
        )
        AND (v_type IS NULL OR c.type_client = v_type)
        AND (v_ville IS NULL OR c.ville ILIKE '%'||v_ville||'%')
        AND (v_actif IS NULL OR c.actif = v_actif)
    )
    SELECT 
        (SELECT count(*) FROM base_search),
        COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.nom), '[]'::jsonb)
    INTO v_total, v_items
    FROM (
        SELECT * FROM base_search
        ORDER BY nom ASC
        LIMIT GREATEST(_limit,1) OFFSET GREATEST(_offset,0)
    ) x;

    RETURN jsonb_build_object('total', COALESCE(v_total, 0), 'items', v_items);
END; $$;
