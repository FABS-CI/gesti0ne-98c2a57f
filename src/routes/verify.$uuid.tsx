import { createFileRoute } from '@tanstack/react-router';
import { useQuery } from '@tanstack/react-query';
import {
  CheckCircle2,
  XCircle,
  Loader2,
  FileText,
  Calendar,
  User,
  ArrowLeft,
  ShieldAlert,
  ShieldOff,
  Info,
} from 'lucide-react';
import { formatFCFA, formatDate } from '@/lib/format';
import { Button } from '@/components/ui/button';

export const Route = createFileRoute('/verify/$uuid')({
  validateSearch: (search: Record<string, unknown>) => ({
    t: typeof search['t'] === 'string' ? (search['t'] as string) : undefined,
  }),
  head: () => ({
    meta: [
      { title: 'Vérification de document — GESTI-ONE' },
      {
        name: 'description',
        content:
          "Vérifiez l'authenticité d'un document commercial certifié par EDITIONS FABS-CI.",
      },
      { property: 'og:title', content: 'Vérification de document — GESTI-ONE' },
      {
        property: 'og:description',
        content: "Contrôle public d'authenticité des documents certifiés.",
      },
      { property: 'og:type', content: 'website' },
      { name: 'twitter:card', content: 'summary' },
      { name: 'robots', content: 'noindex' },
    ],
  }),
  component: VerificationPage,
});

type VerifyResponse = {
  status: 'AUTHENTIC' | 'REVOKED' | 'CANCELLED' | 'TAMPERED' | 'UNCERTIFIED';
  reason?: string | null;
  docType: string;
  reference: string;
  date: string | null;
  client_nom: string | null;
  representant_nom: string | null;
  montant: number | null;
  certified_at?: string | null;
  canonical_hash?: string | null;
  signature_algorithm?: string | null;
};

const STATUS_UI: Record<
  VerifyResponse['status'],
  { title: string; subtitle: string; tone: string; ring: string; Icon: typeof CheckCircle2 }
> = {
  AUTHENTIC: {
    title: 'Authenticité Confirmée',
    subtitle: 'DOCUMENT AUTHENTIQUE',
    tone: 'text-green-600',
    ring: 'bg-green-50 border-green-100',
    Icon: CheckCircle2,
  },
  REVOKED: {
    title: 'Document Révoqué',
    subtitle: 'CERTIFICATION RÉVOQUÉE',
    tone: 'text-orange-600',
    ring: 'bg-orange-50 border-orange-100',
    Icon: ShieldOff,
  },
  CANCELLED: {
    title: 'Document Annulé',
    subtitle: 'DOCUMENT ANNULÉ',
    tone: 'text-orange-600',
    ring: 'bg-orange-50 border-orange-100',
    Icon: ShieldOff,
  },
  TAMPERED: {
    title: 'Intégrité Compromise',
    subtitle: 'CONTENU MODIFIÉ APRÈS CERTIFICATION',
    tone: 'text-red-600',
    ring: 'bg-red-50 border-red-100',
    Icon: ShieldAlert,
  },
  UNCERTIFIED: {
    title: 'Document Non Certifié',
    subtitle: 'AUCUNE SIGNATURE NUMÉRIQUE',
    tone: 'text-slate-600',
    ring: 'bg-slate-100 border-slate-200',
    Icon: Info,
  },
};

function VerificationPage() {
  const { uuid } = Route.useParams();
  const { t } = Route.useSearch();

  const { data, isLoading, error } = useQuery<VerifyResponse>({
    queryKey: ['verify-doc', uuid, t ?? null],
    queryFn: async () => {
      const response = await fetch(
        `/api/public/verify-doc/${encodeURIComponent(uuid)}${t ? `?t=${encodeURIComponent(t)}` : ''}`,
      );
      if (!response.ok) {
        if (response.status === 404) throw new Error('Document non trouvé');
        if (response.status === 429) throw new Error('Trop de vérifications, réessayez plus tard');
        throw new Error('Erreur de vérification');
      }
      return response.json();
    },
    staleTime: 1000 * 60 * 5,
    retry: 1,
  });

  const handleBack = () => {
    window.location.href = 'https://editionsfabs.ci';
  };

  const ui = data ? STATUS_UI[data.status] ?? STATUS_UI.UNCERTIFIED : null;

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-8 text-center space-y-6 border border-slate-100">
        <div className="flex justify-center">
          <img src="/fabs-logo.png" alt="EDITIONS FABS-CI" className="h-24 w-auto object-contain mb-2" />
        </div>

        {isLoading ? (
          <div className="flex flex-col items-center space-y-4 py-8">
            <Loader2 className="h-12 w-12 text-blue-600 animate-spin" />
            <p className="text-slate-500 font-medium">Vérification de l'authenticité...</p>
          </div>
        ) : error || !data || !ui ? (
          <div className="space-y-6 py-4">
            <div className="flex justify-center">
              <div className="bg-red-50 p-6 rounded-full border border-red-100">
                <XCircle className="h-16 w-16 text-red-500" />
              </div>
            </div>

            <div className="space-y-2">
              <h1 className="text-2xl font-black text-red-600 uppercase tracking-tighter">Document Invalide</h1>
              <div className="h-1 w-12 bg-red-600 mx-auto rounded-full" />
            </div>

            <p className="text-slate-600 leading-relaxed px-4">
              {(error as Error | null)?.message ??
                "Nous n'avons trouvé aucun document authentique correspondant à ce code dans notre base de données."}
            </p>

            <div className="pt-4">
              <Button
                variant="outline"
                className="w-full border-slate-200 hover:bg-slate-50 text-slate-700"
                onClick={handleBack}
              >
                <ArrowLeft className="mr-2 h-4 w-4" />
                Retour au site officiel
              </Button>
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            <div className="flex justify-center">
              <div className={`p-6 rounded-full border ${ui.ring}`}>
                <ui.Icon className={`h-16 w-16 ${ui.tone}`} />
              </div>
            </div>

            <div className="space-y-2">
              <h1 className="text-2xl font-black text-slate-900 uppercase tracking-tighter">{ui.title}</h1>
              <p className={`font-bold text-lg uppercase tracking-wide ${ui.tone}`}>
                {data.docType?.toUpperCase()} — {ui.subtitle}
              </p>
              {data.reason && (
                <p className="text-sm text-slate-500 italic">Motif : {data.reason}</p>
              )}
            </div>

            <div className="bg-slate-50 rounded-xl p-6 text-left space-y-4 border border-slate-200 shadow-inner">
              <div className="flex items-start gap-3">
                <FileText className="h-5 w-5 text-blue-600 mt-0.5" />
                <div>
                  <p className="text-[10px] text-slate-400 uppercase font-black tracking-widest">Référence Officielle</p>
                  <p className="font-mono text-slate-900 font-bold text-lg leading-none mt-1">{data.reference}</p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4">
                <div className="flex items-start gap-3">
                  <Calendar className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <p className="text-[10px] text-slate-400 uppercase font-black tracking-widest">Émission</p>
                    <p className="text-slate-900 font-bold">{data.date ? formatDate(data.date) : '—'}</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <User className="h-5 w-5 text-blue-600 mt-0.5 shrink-0" />
                  <div className="min-w-0 flex-1">
                    <p className="text-[10px] text-slate-400 uppercase font-black tracking-widest">Client & Représentant</p>
                    <p className="text-slate-900 font-bold break-words leading-tight">
                      {data.client_nom}
                      {data.representant_nom && (
                        <span className="block text-[11px] text-slate-500 font-medium mt-0.5 italic">
                          Rep : {data.representant_nom}
                        </span>
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <div className="pt-4 border-t border-slate-200">
                <div className="flex justify-between items-center">
                  <p className="text-slate-500 font-medium">Net à Payer</p>
                  <p className="text-2xl font-black text-blue-900">{formatFCFA(data.montant ?? 0)}</p>
                </div>
              </div>

              {data.certified_at && (
                <div className="pt-4 border-t border-slate-200 space-y-1">
                  <p className="text-[10px] text-slate-400 uppercase font-black tracking-widest">
                    Certification numérique
                  </p>
                  <p className="text-[11px] text-slate-500">
                    Certifié le {formatDate(data.certified_at)} • {data.signature_algorithm ?? 'Ed25519'}
                  </p>
                  {data.canonical_hash && (
                    <p className="font-mono text-[10px] text-slate-400 break-all">
                      {data.canonical_hash}
                    </p>
                  )}
                </div>
              )}
            </div>

            <div className="bg-blue-50/50 p-4 rounded-lg border border-blue-100">
              <p className="text-[11px] text-blue-800 leading-relaxed font-medium">
                {data.status === 'AUTHENTIC'
                  ? "Confirmation officielle du système ERP EDITIONS FABS-CI : ce document est signé numériquement et enregistré dans notre registre."
                  : data.status === 'UNCERTIFIED'
                    ? "Ce document existe dans notre registre mais n'a pas été signé numériquement. Contactez EDITIONS FABS-CI pour confirmation."
                    : "Ce document ne peut plus être considéré comme valide. Contactez EDITIONS FABS-CI avant tout paiement."}
              </p>
            </div>

            <Button
              variant="ghost"
              className="w-full text-slate-400 text-xs hover:text-slate-600"
              onClick={handleBack}
            >
              Fermer la vérification
            </Button>
          </div>
        )}
      </div>

      <div className="mt-8 flex flex-col items-center space-y-2 opacity-60">
        <p className="text-slate-500 text-[10px] font-bold uppercase tracking-[0.2em]">
          Certification Digitale • Editions FABS-CI
        </p>
        <p className="text-slate-400 text-[10px]">
          © {new Date().getFullYear()} Tous droits réservés.
        </p>
      </div>
    </div>
  );
}
