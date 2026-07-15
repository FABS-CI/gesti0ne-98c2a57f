CREATE OR REPLACE FUNCTION public.recalculer_livraison_commande(_livraison_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v_cmd uuid; v_nb int; v_expediee int; v_livree int; v_qte_cmd int; v_pct int; v_statut public.statut_livraison_cmd;
BEGIN
  SELECT commande_id, quantite_commandee, statut INTO v_cmd, v_qte_cmd, v_statut
    FROM public.livraisons_commande WHERE livraison_id = _livraison_id;
  SELECT COUNT(*) INTO v_nb FROM public.colis WHERE commande_id = v_cmd;
  SELECT
    COUNT(*) FILTER (WHERE statut_logistique IN ('en_cours_livraison','arrive_client','livre','depose_gare','en_cours_expedition','arrive_ville','remis_client')),
    COUNT(*) FILTER (WHERE statut_logistique IN ('livre','remis_client'))
  INTO v_expediee, v_livree FROM public.colis WHERE commande_id = v_cmd;
  v_pct := CASE v_statut
    WHEN 'commande_creee' THEN 10 WHEN 'preparation' THEN 25 WHEN 'colisage_termine' THEN 50
    WHEN 'en_attente_expedition' THEN 60 WHEN 'expediee' THEN 75 WHEN 'en_cours_livraison' THEN 85
    WHEN 'livraison_partielle' THEN 90 WHEN 'livree' THEN 100 WHEN 'livraison_confirmee' THEN 100 ELSE 0 END;
  UPDATE public.livraisons_commande SET
    nb_cartons = COALESCE(v_nb,0),
    quantite_expediee = CASE WHEN COALESCE(v_nb,0)=0 THEN 0 ELSE ROUND(v_qte_cmd::numeric * v_expediee::numeric / v_nb::numeric)::int END,
    quantite_livree = CASE WHEN COALESCE(v_nb,0)=0 THEN 0 ELSE ROUND(v_qte_cmd::numeric * v_livree::numeric / v_nb::numeric)::int END,
    progression_pct = v_pct, derniere_maj = now(), updated_at = now()
  WHERE livraison_id = _livraison_id;
END $function$;

-- Backfill historique
UPDATE public.livraisons_commande
   SET progression_pct = 100, derniere_maj = now(), updated_at = now()
 WHERE statut IN ('livree','livraison_confirmee')
   AND progression_pct IS DISTINCT FROM 100;