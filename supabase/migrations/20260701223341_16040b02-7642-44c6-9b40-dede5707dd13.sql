DO $mig$
DECLARE
  v_ann text;
  v_sup text;
BEGIN
  SELECT pg_get_functiondef(oid) INTO v_ann FROM pg_proc WHERE proname='annuler_colisage';
  v_ann := replace(
    v_ann,
    'v_bl.statut NOT IN (''a_preparer'', ''colisage_en_cours'', ''colisage_termine'')',
    'v_bl.statut NOT IN (''a_preparer'', ''colisage_en_cours'')'
  );
  EXECUTE v_ann;

  SELECT pg_get_functiondef(oid) INTO v_sup FROM pg_proc WHERE proname='supprimer_colisage';
  v_sup := replace(
    v_sup,
    'v_bl.statut NOT IN (''a_preparer'', ''colisage_en_cours'', ''colisage_termine'', ''annule'', ''colisage_supprime'')',
    'v_bl.statut NOT IN (''a_preparer'', ''colisage_en_cours'', ''annule'', ''colisage_supprime'')'
  );
  EXECUTE v_sup;
END
$mig$;