
-- =========================================================================
-- LOT C : Fondation structurelle — FK manquantes + CHECK statuts + index
-- Base vérifiée : 0 orphelin, 0 commande existante.
-- =========================================================================

-- 1) FK manquantes vers commandes(commande_id)
-- Politique métier :
--   * factures, bons_livraison  -> RESTRICT (protection comptable/logistique)
--   * proformas, retours        -> SET NULL (documents conservés, lien effacé)
--   * livraisons, colis, colisages -> SET NULL (suivent leur BL en cascade)

ALTER TABLE public.proformas
  ADD CONSTRAINT proformas_commande_id_fkey
  FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id)
  ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.factures
  ADD CONSTRAINT factures_commande_id_fkey
  FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id)
  ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.bons_livraison
  ADD CONSTRAINT bons_livraison_commande_id_fkey
  FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id)
  ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public.livraisons
  ADD CONSTRAINT livraisons_commande_id_fkey
  FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id)
  ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.colis
  ADD CONSTRAINT colis_commande_id_fkey
  FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id)
  ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.colisages
  ADD CONSTRAINT colisages_commande_id_fkey
  FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id)
  ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.retours
  ADD CONSTRAINT retours_commande_id_fkey
  FOREIGN KEY (commande_id) REFERENCES public.commandes(commande_id)
  ON UPDATE CASCADE ON DELETE SET NULL;

-- 2) Index de performance sur les colonnes de liaison
CREATE INDEX IF NOT EXISTS idx_proformas_commande_id      ON public.proformas(commande_id);
CREATE INDEX IF NOT EXISTS idx_factures_commande_id       ON public.factures(commande_id);
CREATE INDEX IF NOT EXISTS idx_bons_livraison_commande_id ON public.bons_livraison(commande_id);
CREATE INDEX IF NOT EXISTS idx_livraisons_commande_id     ON public.livraisons(commande_id);
CREATE INDEX IF NOT EXISTS idx_colis_commande_id          ON public.colis(commande_id);
CREATE INDEX IF NOT EXISTS idx_colisages_commande_id      ON public.colisages(commande_id);
CREATE INDEX IF NOT EXISTS idx_retours_commande_id        ON public.retours(commande_id);

-- 3) CHECK constraints sur les statuts métier
-- Statuts commandes (union code TS + RPC observés)
ALTER TABLE public.commandes
  ADD CONSTRAINT commandes_statut_check
  CHECK (statut IN (
    'brouillon',
    'soumise',
    'en_attente_validation',
    'validee',
    'livraison_en_cours',
    'facturee',
    'livree',
    'annulee'
  ));

-- Statuts factures
ALTER TABLE public.factures
  ADD CONSTRAINT factures_statut_check
  CHECK (statut IN (
    'brouillon',
    'emise',
    'impayee',
    'partielle',
    'payee',
    'annulee'
  ));

-- Statuts bons_livraison
ALTER TABLE public.bons_livraison
  ADD CONSTRAINT bons_livraison_statut_check
  CHECK (statut IN (
    'a_preparer',
    'en_preparation',
    'pret',
    'expedie',
    'livre',
    'annulee'
  ));

-- Statuts paiements
ALTER TABLE public.paiements
  ADD CONSTRAINT paiements_statut_check
  CHECK (statut IN (
    'en_attente_validation',
    'valide',
    'annule',
    'rejete'
  ));

COMMENT ON CONSTRAINT commandes_statut_check ON public.commandes IS
  'Lot C — Verrou métier : statuts autorisés d''une commande.';
COMMENT ON CONSTRAINT factures_commande_id_fkey ON public.factures IS
  'Lot C — Une facture ne peut exister sans commande source ; la suppression de la commande est bloquée tant qu''une facture y est rattachée.';
COMMENT ON CONSTRAINT bons_livraison_commande_id_fkey ON public.bons_livraison IS
  'Lot C — Un BL ne peut exister sans commande source ; la suppression de la commande est bloquée tant qu''un BL y est rattaché.';
