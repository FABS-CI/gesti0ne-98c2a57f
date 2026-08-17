-- Update global_search to include cartons (colis)
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
            'Clients' as "group", 
            nom as label, 
            concat_ws(' · ', ville, representant, telephone) as sub,
            '/clients/$clientId' as "to",
            jsonb_build_object('clientId', client_id) as params,
            1 as priority
         FROM public.clients
         WHERE nom ILIKE '%'||_q||'%' 
            OR reference ILIKE '%'||_q||'%'
            OR (v_q_norm <> '' AND phone_normalized LIKE '%'||v_q_norm||'%')
            OR telephone ILIKE '%'||_q||'%'
         LIMIT 10)
        
        UNION ALL
        
        -- Produits
        (SELECT 
            produit_id::text as id, 
            'Produits' as "group", 
            titre as label, 
            reference as sub,
            '/produits/$produitId' as "to",
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
            'Factures' as "group", 
            reference as label, 
            client_nom as sub,
            '/factures/$factureId' as "to",
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
            'Bons de livraison' as "group", 
            reference as label, 
            client_nom as sub,
            '/bons-livraison' as "to",
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
            'Bons de commande' as "group", 
            reference as label, 
            client_nom as sub,
            '/commandes/$commandeId' as "to",
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
            'Proformas' as "group", 
            reference as label, 
            client_nom as sub,
            '/proformas/$proformaId' as "to",
            jsonb_build_object('proformaId', proforma_id) as params,
            6 as priority
         FROM public.proformas
         WHERE reference ILIKE '%'||_q||'%' 
            OR client_nom ILIKE '%'||_q||'%'
         LIMIT 5)
         
        UNION ALL
        
        -- Cartons (Scan)
        (SELECT 
            c.colis_id::text as id, 
            'Cartons' as "group", 
            c.reference as label, 
            concat_ws(' · ', 'Carton ' || c.numero_carton, bl.client_nom) as sub,
            '/colisage/$blId' as "to",
            jsonb_build_object('blId', c.bl_id) as params,
            7 as priority
         FROM public.colis c
         JOIN public.bons_livraison bl ON bl.bl_id = c.bl_id
         WHERE c.reference ILIKE '%'||_q||'%' 
         LIMIT 5)

        UNION ALL
        
        -- Utilisateurs / Profiles (Recherche par téléphone)
        (SELECT 
            id::text as id, 
            'Utilisateurs' as "group", 
            nom_complet as label, 
            telephone as sub,
            '/utilisateurs' as "to",
            '{}'::jsonb as params,
            8 as priority
         FROM public.profiles
         WHERE nom_complet ILIKE '%'||_q||'%' 
            OR (v_q_norm <> '' AND phone_normalized LIKE '%'||v_q_norm||'%')
            OR telephone ILIKE '%'||_q||'%'
         LIMIT 5)
    )
    SELECT jsonb_agg(h ORDER BY priority, label) INTO v_results
    FROM (SELECT id, "group", label, sub, "to", params, priority FROM hits) h;

    RETURN COALESCE(v_results, '[]'::jsonb);
END; $$;
