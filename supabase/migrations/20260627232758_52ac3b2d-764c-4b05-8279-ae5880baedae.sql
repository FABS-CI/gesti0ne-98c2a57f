CREATE SEQUENCE IF NOT EXISTS public.colis_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.fne_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.inventaires_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.workflow_ref_seq START 1;

CREATE TABLE public.colis (
  colis_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('COL-' || lpad(nextval('public.colis_ref_seq')::text, 5, '0')),
  destinataire TEXT,
  contenu TEXT,
  poids NUMERIC NOT NULL DEFAULT 0,
  transporteur TEXT,
  date_envoi DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_preparation',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.notifications (
  notification_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titre TEXT NOT NULL,
  message TEXT,
  type_notification TEXT NOT NULL DEFAULT 'info',
  lu BOOLEAN NOT NULL DEFAULT false,
  date_notification DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.fne_factures (
  fne_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('FNE-' || lpad(nextval('public.fne_ref_seq')::text, 5, '0')),
  facture_id UUID REFERENCES public.factures(facture_id) ON DELETE SET NULL,
  client_nom TEXT,
  montant NUMERIC NOT NULL DEFAULT 0,
  date_emission DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_attente',
  code_dgi TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.inventaires (
  inventaire_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('INV-' || lpad(nextval('public.inventaires_ref_seq')::text, 5, '0')),
  produit_nom TEXT,
  stock_theorique INTEGER NOT NULL DEFAULT 0,
  stock_compte INTEGER NOT NULL DEFAULT 0,
  ecart INTEGER NOT NULL DEFAULT 0,
  date_inventaire DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_cours',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.documents (
  document_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  titre TEXT NOT NULL,
  type_document TEXT NOT NULL DEFAULT 'autre',
  description TEXT,
  date_document DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'actif',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.workflow_approvals (
  approval_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE DEFAULT ('WF-' || lpad(nextval('public.workflow_ref_seq')::text, 5, '0')),
  type_demande TEXT NOT NULL DEFAULT 'achat',
  demandeur TEXT,
  objet TEXT,
  montant NUMERIC NOT NULL DEFAULT 0,
  date_demande DATE NOT NULL DEFAULT CURRENT_DATE,
  statut TEXT NOT NULL DEFAULT 'en_attente',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.parametres (
  parametre_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  cle TEXT NOT NULL UNIQUE,
  valeur TEXT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'colis','notifications','fne_factures','inventaires','documents','workflow_approvals','parametres'
  ] LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated;', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role;', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE POLICY "Staff select %1$s" ON public.%1$I FOR SELECT TO authenticated USING (true);', t);
    EXECUTE format('CREATE POLICY "Staff insert %1$s" ON public.%1$I FOR INSERT TO authenticated WITH CHECK (true);', t);
    EXECUTE format('CREATE POLICY "Staff update %1$s" ON public.%1$I FOR UPDATE TO authenticated USING (true) WITH CHECK (true);', t);
    EXECUTE format('CREATE POLICY "Staff delete %1$s" ON public.%1$I FOR DELETE TO authenticated USING (true);', t);
    EXECUTE format('CREATE TRIGGER update_%1$s_updated_at BEFORE UPDATE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();', t);
  END LOOP;
END $$;