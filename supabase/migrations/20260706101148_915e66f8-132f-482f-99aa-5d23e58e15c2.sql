-- Index sur les clés étrangères RH (manquants)
CREATE INDEX IF NOT EXISTS idx_absences_employe_id ON public.absences(employe_id);
CREATE INDEX IF NOT EXISTS idx_conges_employe_id ON public.conges(employe_id);
CREATE INDEX IF NOT EXISTS idx_contrats_employe_id ON public.contrats(employe_id);
CREATE INDEX IF NOT EXISTS idx_evaluations_employe_id ON public.evaluations(employe_id);
CREATE INDEX IF NOT EXISTS idx_bulletins_paie_employe_id ON public.bulletins_paie(employe_id);
CREATE INDEX IF NOT EXISTS idx_employes_fonction_id ON public.employes(fonction_id);
CREATE INDEX IF NOT EXISTS idx_fonctions_departement_id ON public.fonctions(departement_id);

-- Index sur colonnes de filtrage frequent
CREATE INDEX IF NOT EXISTS idx_conges_statut ON public.conges(statut);
CREATE INDEX IF NOT EXISTS idx_conges_dates ON public.conges(date_debut, date_fin);
CREATE INDEX IF NOT EXISTS idx_absences_dates ON public.absences(date_debut, date_fin);
CREATE INDEX IF NOT EXISTS idx_bulletins_paie_periode ON public.bulletins_paie(periode);
CREATE INDEX IF NOT EXISTS idx_bulletins_paie_statut ON public.bulletins_paie(statut);
CREATE INDEX IF NOT EXISTS idx_employes_actif ON public.employes(actif);

-- Coherence des dates (immutables, safe en CHECK)
ALTER TABLE public.conges
  DROP CONSTRAINT IF EXISTS conges_dates_coherentes;
ALTER TABLE public.conges
  ADD CONSTRAINT conges_dates_coherentes CHECK (date_fin >= date_debut);

ALTER TABLE public.absences
  DROP CONSTRAINT IF EXISTS absences_dates_coherentes;
ALTER TABLE public.absences
  ADD CONSTRAINT absences_dates_coherentes CHECK (date_fin >= date_debut);
