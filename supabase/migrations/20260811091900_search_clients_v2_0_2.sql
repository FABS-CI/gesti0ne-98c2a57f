-- GESTI-ONE 2.0.2 — Amélioration de la recherche client par téléphone
-- Normalisation et indexation des numéros de téléphone

-- 1. Ajout des colonnes de recherche normalisées
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS phone_normalized text;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS phone_secondary_normalized text;

-- 2. Fonction de normalisation des numéros (Format 225 Côte d'Ivoire)
CREATE OR REPLACE FUNCTION public.normalize_phone(phone text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    cleaned text;
BEGIN
    IF phone IS NULL THEN RETURN NULL; END IF;
    
    -- Supprimer tout ce qui n'est pas un chiffre
    cleaned := regexp_replace(phone, '[^0-9]', '', 'g');
    
    -- Gérer le préfixe international 00225 ou 225
    IF cleaned LIKE '00225%' THEN
        cleaned := substr(cleaned, 6);
    ELSIF cleaned LIKE '225%' THEN
        -- Attention : 225 peut être le début d'un numéro local si on ne fait pas attention
        -- En CI, les nouveaux numéros sont à 10 chiffres. Si on a 13 chiffres commençant par 225, c'est l'indicatif.
        IF length(cleaned) >= 11 THEN
            cleaned := substr(cleaned, 4);
        END IF;
    END IF;
    
    -- En Côte d'Ivoire (10 chiffres depuis 2021) :
    -- Si le numéro commence par un 0, on le garde souvent dans la saisie locale
    -- La normalisation GESTI-ONE vise la comparaison robuste.
    RETURN cleaned;
END;
$$;

-- 3. Trigger pour maintenir les champs normalisés
CREATE OR REPLACE FUNCTION public.trg_normalize_client_phones()
RETURNS trigger AS $$
BEGIN
    NEW.phone_normalized := public.normalize_phone(NEW.telephone);
    NEW.phone_secondary_normalized := public.normalize_phone(NEW.telephone_secondaire);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_client_phones_upsert ON public.clients;
CREATE TRIGGER trg_normalize_client_phones_upsert
BEFORE INSERT OR UPDATE ON public.clients
FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_client_phones();

-- 4. Initialisation des données existantes
UPDATE public.clients SET 
    phone_normalized = public.normalize_phone(telephone),
    phone_secondary_normalized = public.normalize_phone(telephone_secondaire);

-- 5. Indexation pour performance
CREATE INDEX IF NOT EXISTS idx_clients_phone_normalized ON public.clients (phone_normalized) WHERE phone_normalized IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_clients_phone_secondary_normalized ON public.clients (phone_secondary_normalized) WHERE phone_secondary_normalized IS NOT NULL;

-- 6. Mise à jour de la RPC de recherche CRM
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
            OR c.prenom ILIKE '%'||v_q||'%' 
            OR c.raison_sociale ILIKE '%'||v_q||'%' 
            OR COALESCE(c.reference,'') ILIKE '%'||v_q||'%'
            OR c.ville ILIKE '%'||v_q||'%'
            OR (v_q_norm <> '' AND (
                   c.phone_normalized LIKE '%'||v_q_norm||'%' 
                OR c.phone_secondary_normalized LIKE '%'||v_q_norm||'%'
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

GRANT EXECUTE ON FUNCTION public.normalize_phone(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_clients_crm(jsonb, integer, integer) TO authenticated;
