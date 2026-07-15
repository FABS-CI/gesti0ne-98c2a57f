
-- ============================================================
-- Lot 1 : Audit lecture seule — Comptabilité & Finances
-- ============================================================

-- Écritures dont le total débit ≠ total crédit
CREATE OR REPLACE FUNCTION public.audit_compta_ecritures_desequilibrees()
RETURNS TABLE (
  ecriture_id uuid,
  reference text,
  date_ecriture date,
  journal text,
  libelle text,
  total_debit numeric,
  total_credit numeric,
  ecart numeric
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT e.ecriture_id, e.reference, e.date_ecriture, e.journal, e.libelle,
    COALESCE(SUM(l.debit),0) AS total_debit,
    COALESCE(SUM(l.credit),0) AS total_credit,
    (COALESCE(SUM(l.debit),0) - COALESCE(SUM(l.credit),0)) AS ecart
  FROM public.ecritures_comptables e
  LEFT JOIN public.ecriture_lignes l ON l.ecriture_id = e.ecriture_id
  GROUP BY e.ecriture_id, e.reference, e.date_ecriture, e.journal, e.libelle
  HAVING COALESCE(SUM(l.debit),0) <> COALESCE(SUM(l.credit),0)
  ORDER BY e.date_ecriture DESC;
$$;

-- Factures : cohérence montant_paye vs somme réelle des paiements
CREATE OR REPLACE FUNCTION public.audit_compta_factures_paiements()
RETURNS TABLE (
  facture_id uuid,
  reference text,
  client_nom text,
  montant_total numeric,
  montant_paye_enregistre numeric,
  montant_paye_calcule numeric,
  ecart numeric,
  statut text,
  probleme text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  WITH pay AS (
    SELECT facture_id, COALESCE(SUM(montant),0) AS total
    FROM public.paiements
    WHERE statut IS NULL OR statut <> 'annule'
    GROUP BY facture_id
  )
  SELECT f.facture_id, f.reference, f.client_nom,
    f.montant_total,
    COALESCE(f.montant_paye,0) AS montant_paye_enregistre,
    COALESCE(p.total,0) AS montant_paye_calcule,
    (COALESCE(p.total,0) - COALESCE(f.montant_paye,0)) AS ecart,
    f.statut,
    CASE
      WHEN COALESCE(p.total,0) > f.montant_total THEN 'SURPAIEMENT'
      WHEN COALESCE(p.total,0) <> COALESCE(f.montant_paye,0) THEN 'MONTANT_PAYE_INCOHERENT'
      WHEN COALESCE(p.total,0) >= f.montant_total AND f.statut NOT IN ('payee','soldee') THEN 'STATUT_INCOHERENT'
      WHEN COALESCE(p.total,0) = 0 AND f.statut IN ('payee','soldee') THEN 'STATUT_INCOHERENT'
      ELSE NULL
    END AS probleme
  FROM public.factures f
  LEFT JOIN pay p ON p.facture_id = f.facture_id
  WHERE
    COALESCE(p.total,0) > f.montant_total
    OR COALESCE(p.total,0) <> COALESCE(f.montant_paye,0)
    OR (COALESCE(p.total,0) >= f.montant_total AND f.statut NOT IN ('payee','soldee'))
    OR (COALESCE(p.total,0) = 0 AND f.statut IN ('payee','soldee'))
  ORDER BY ABS(COALESCE(p.total,0) - COALESCE(f.montant_paye,0)) DESC;
$$;

-- Soldes clients : enregistré vs recalculé (factures - paiements)
CREATE OR REPLACE FUNCTION public.audit_compta_soldes_clients()
RETURNS TABLE (
  client_id uuid,
  reference text,
  nom text,
  solde_enregistre numeric,
  solde_calcule numeric,
  ecart numeric
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  WITH fac AS (
    SELECT client_id, COALESCE(SUM(montant_total),0) AS tot_fac,
                     COALESCE(SUM(montant_paye),0) AS tot_pay
    FROM public.factures
    WHERE statut IS NULL OR statut <> 'annulee'
    GROUP BY client_id
  )
  SELECT c.client_id, c.reference, c.nom,
    COALESCE(c.solde,0) AS solde_enregistre,
    (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0)) AS solde_calcule,
    (COALESCE(c.solde,0) - (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0))) AS ecart
  FROM public.clients c
  LEFT JOIN fac f ON f.client_id = c.client_id
  WHERE COALESCE(c.solde,0) <> (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0))
  ORDER BY ABS(COALESCE(c.solde,0) - (COALESCE(f.tot_fac,0) - COALESCE(f.tot_pay,0))) DESC;
$$;

-- Paiements orphelins (facture manquante)
CREATE OR REPLACE FUNCTION public.audit_compta_paiements_orphelins()
RETURNS TABLE (
  paiement_id uuid,
  reference text,
  facture_id uuid,
  montant numeric,
  date_paiement date,
  probleme text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT p.paiement_id, p.reference, p.facture_id, p.montant, p.date_paiement,
    CASE
      WHEN p.facture_id IS NULL THEN 'SANS_FACTURE'
      WHEN f.facture_id IS NULL THEN 'FACTURE_INEXISTANTE'
      WHEN p.montant <= 0 THEN 'MONTANT_INVALIDE'
    END AS probleme
  FROM public.paiements p
  LEFT JOIN public.factures f ON f.facture_id = p.facture_id
  WHERE p.facture_id IS NULL OR f.facture_id IS NULL OR p.montant <= 0;
$$;

-- Doublons de paiement
CREATE OR REPLACE FUNCTION public.audit_compta_doublons_paiement()
RETURNS TABLE (
  facture_id uuid,
  date_paiement date,
  mode_paiement text,
  montant numeric,
  nb_doublons bigint,
  paiement_ids uuid[]
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT facture_id, date_paiement, mode_paiement, montant,
         COUNT(*) AS nb_doublons,
         array_agg(paiement_id) AS paiement_ids
  FROM public.paiements
  WHERE facture_id IS NOT NULL AND (statut IS NULL OR statut <> 'annule')
  GROUP BY facture_id, date_paiement, mode_paiement, montant
  HAVING COUNT(*) > 1;
$$;

-- Résumé global + verdict
CREATE OR REPLACE FUNCTION public.audit_finances_anomalies()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_desequilibrees int;
  v_factures_pb int;
  v_soldes_pb int;
  v_orphelins int;
  v_doublons int;
  v_total_ecritures int;
  v_total_paiements int;
  v_total_factures int;
BEGIN
  SELECT COUNT(*) INTO v_desequilibrees FROM public.audit_compta_ecritures_desequilibrees();
  SELECT COUNT(*) INTO v_factures_pb FROM public.audit_compta_factures_paiements();
  SELECT COUNT(*) INTO v_soldes_pb FROM public.audit_compta_soldes_clients();
  SELECT COUNT(*) INTO v_orphelins FROM public.audit_compta_paiements_orphelins();
  SELECT COUNT(*) INTO v_doublons FROM public.audit_compta_doublons_paiement();
  SELECT COUNT(*) INTO v_total_ecritures FROM public.ecritures_comptables;
  SELECT COUNT(*) INTO v_total_paiements FROM public.paiements;
  SELECT COUNT(*) INTO v_total_factures FROM public.factures;

  RETURN jsonb_build_object(
    'generated_at', now(),
    'total_ecritures', v_total_ecritures,
    'total_factures', v_total_factures,
    'total_paiements', v_total_paiements,
    'ecritures_desequilibrees', v_desequilibrees,
    'factures_incoherentes', v_factures_pb,
    'soldes_clients_incoherents', v_soldes_pb,
    'paiements_orphelins', v_orphelins,
    'doublons_paiement', v_doublons,
    'verdict', CASE
      WHEN v_desequilibrees=0 AND v_factures_pb=0 AND v_soldes_pb=0 AND v_orphelins=0 AND v_doublons=0
      THEN 'GO_PRODUCTION' ELSE 'ANOMALIES_DETECTEES' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.audit_compta_ecritures_desequilibrees() FROM public, anon;
REVOKE ALL ON FUNCTION public.audit_compta_factures_paiements() FROM public, anon;
REVOKE ALL ON FUNCTION public.audit_compta_soldes_clients() FROM public, anon;
REVOKE ALL ON FUNCTION public.audit_compta_paiements_orphelins() FROM public, anon;
REVOKE ALL ON FUNCTION public.audit_compta_doublons_paiement() FROM public, anon;
REVOKE ALL ON FUNCTION public.audit_finances_anomalies() FROM public, anon;

GRANT EXECUTE ON FUNCTION public.audit_compta_ecritures_desequilibrees() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.audit_compta_factures_paiements() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.audit_compta_soldes_clients() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.audit_compta_paiements_orphelins() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.audit_compta_doublons_paiement() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.audit_finances_anomalies() TO authenticated, service_role;
