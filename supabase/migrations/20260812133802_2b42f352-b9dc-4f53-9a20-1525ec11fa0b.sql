-- GESTI-ONE 2.0.3 — Optimisation de la Recherche Globale (v2)
-- Correction : retrait de raison_sociale qui n'existe pas dans clients

-- 1. Extension pg_trgm
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Normalisation pour profiles et employes
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_normalized text;
ALTER TABLE public.employes ADD COLUMN IF NOT EXISTS phone_normalized text;

-- Triggers pour profiles
CREATE OR REPLACE FUNCTION public.trg_normalize_profile_phones()
RETURNS trigger AS $$
BEGIN
    NEW.phone_normalized := public.normalize_phone(NEW.telephone);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_profile_phones_upsert ON public.profiles;
CREATE TRIGGER trg_normalize_profile_phones_upsert
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_profile_phones();

-- Triggers pour employes
CREATE OR REPLACE FUNCTION public.trg_normalize_employe_phones()
RETURNS trigger AS $$
BEGIN
    NEW.phone_normalized := public.normalize_phone(NEW.telephone);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_employe_phones_upsert ON public.employes;
CREATE TRIGGER trg_normalize_employe_phones_upsert
BEFORE INSERT OR UPDATE ON public.employes
FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_employe_phones();

-- Initialisation des données
UPDATE public.profiles SET phone_normalized = public.normalize_phone(telephone);
UPDATE public.employes SET phone_normalized = public.normalize_phone(telephone);

-- 3. Indexation Trigram pour recherche partielle performante
-- Clients
CREATE INDEX IF NOT EXISTS idx_clients_nom_trgm ON public.clients USING gin (nom gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_reference_trgm ON public.clients USING gin (reference gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clients_phone_norm_trgm ON public.clients USING gin (phone_normalized gin_trgm_ops);

-- Profiles (Utilisateurs)
CREATE INDEX IF NOT EXISTS idx_profiles_nom_complet_trgm ON public.profiles USING gin (nom_complet gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_profiles_phone_norm_trgm ON public.profiles USING gin (phone_normalized gin_trgm_ops);

-- Employes
CREATE INDEX IF NOT EXISTS idx_employes_nom_complet_trgm ON public.employes USING gin (nom_complet gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_employes_phone_norm_trgm ON public.employes USING gin (phone_normalized gin_trgm_ops);

-- Documents
CREATE INDEX IF NOT EXISTS idx_factures_ref_trgm ON public.factures USING gin (reference gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_factures_client_trgm ON public.factures USING gin (client_nom gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_bl_ref_trgm ON public.bons_livraison USING gin (reference gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_bl_client_trgm ON public.bons_livraison USING gin (client_nom gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_commandes_ref_trgm ON public.commandes USING gin (reference gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_commandes_client_trgm ON public.commandes USING gin (client_nom gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_proformas_ref_trgm ON public.proformas USING gin (reference gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_proformas_client_trgm ON public.proformas USING gin (client_nom gin_trgm_ops);

-- 4. RPC de recherche globale unifiée
CREATE OR REPLACE FUNCTION public.global_search(_q text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_q_norm text;
    v_results jsonb := '[]'::jsonb;
BEGIN
    IF _q IS NULL OR length(trim(_q)) < 2 THEN
        RETURN '[]'::jsonb;
    END IF;

    v_q_norm := public.normalize_phone(_q);

    WITH hits AS (
        -- Clients
        (SELECT 
            client_id::text as id, 
            'Clients' as group, 
            nom as label, 
            concat_ws(' · ', ville, representant, telephone) as sub,
            '/clients/$clientId' as to,
            jsonb_build_object('clientId', client_id) as params,
            1 as priority
         FROM public.clients
         WHERE nom ILIKE '%'||_q||'%' 
            OR reference ILIKE '%'||_q||'%'
            OR (v_q_norm <> '' AND phone_normalized LIKE '%'||v_q_norm||'%')
         LIMIT 10)
        
        UNION ALL
        
        -- Produits
        (SELECT 
            produit_id::text as id, 
            'Produits' as group, 
            titre as label, 
            reference as sub,
            '/produits/$produitId' as to,
            jsonb_build_object('produitId', produit_id) as params,
            2 as priority
         FROM public.produits
         WHERE titre ILIKE '%'||_q||'%' 
            OR reference ILIKE '%'||_q||'%'
         LIMIT 8)

        UNION ALL

        -- Factures
        (SELECT 
            facture_id::text as id, 
            'Factures' as group, 
            reference as label, 
            client_nom as sub,
            '/factures/$factureId' as to,
            jsonb_build_object('factureId', facture_id) as params,
            3 as priority
         FROM public.factures
         WHERE reference ILIKE '%'||_q||'%' 
            OR client_nom ILIKE '%'||_q||'%'
         LIMIT 5)

        UNION ALL

        -- Bons de livraison
        (SELECT 
            bl_id::text as id, 
            'Bons de livraison' as group, 
            reference as label, 
            client_nom as sub,
            '/bons-livraison' as to,
            '{}'::jsonb as params,
            4 as priority
         FROM public.bons_livraison
         WHERE reference ILIKE '%'||_q||'%' 
            OR client_nom ILIKE '%'||_q||'%'
         LIMIT 5)

        UNION ALL

        -- Commandes
        (SELECT 
            commande_id::text as id, 
            'Bons de commande' as group, 
            reference as label, 
            client_nom as sub,
            '/commandes/$commandeId' as to,
            jsonb_build_object('commandeId', commande_id) as params,
            5 as priority
         FROM public.commandes
         WHERE reference ILIKE '%'||_q||'%' 
            OR client_nom ILIKE '%'||_q||'%'
         LIMIT 5)

        UNION ALL

        -- Proformas
        (SELECT 
            proforma_id::text as id, 
            'Proformas' as group, 
            reference as label, 
            client_nom as sub,
            '/proformas/$proformaId' as to,
            jsonb_build_object('proformaId', proforma_id) as params,
            6 as priority
         FROM public.proformas
         WHERE reference ILIKE '%'||_q||'%' 
            OR client_nom ILIKE '%'||_q||'%'
         LIMIT 5)
         
        UNION ALL
        
        -- Utilisateurs / Profiles (Recherche par téléphone)
        (SELECT 
            id::text as id, 
            'Utilisateurs' as group, 
            nom_complet as label, 
            telephone as sub,
            '/utilisateurs' as to,
            '{}'::jsonb as params,
            7 as priority
         FROM public.profiles
         WHERE nom_complet ILIKE '%'||_q||'%' 
            OR (v_q_norm <> '' AND phone_normalized LIKE '%'||v_q_norm||'%')
         LIMIT 5)
    )
    SELECT jsonb_agg(h ORDER BY priority, label) INTO v_results
    FROM (SELECT id, "group", label, sub, "to", params FROM hits) h;

    RETURN COALESCE(v_results, '[]'::jsonb);
END; $$;

GRANT EXECUTE ON FUNCTION public.global_search(text) TO authenticated;
