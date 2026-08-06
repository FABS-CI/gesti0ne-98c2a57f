import { createFileRoute } from '@tanstack/react-router';
import { useQuery } from '@tanstack/react-query';
import { CheckCircle2, XCircle, Loader2, FileText, Calendar, User, ArrowLeft } from 'lucide-react';
import { formatFCFA, formatDate } from '@/lib/format';
import { Button } from '@/components/ui/button';

export const Route = createFileRoute('/verify/$uuid')({
  component: VerificationPage,
});

function VerificationPage() {
  const { uuid } = Route.useParams();

  const { data, isLoading, error } = useQuery({
    queryKey: ['verify-doc', uuid],
    queryFn: async () => {
      const response = await fetch(`/api/public/verify-doc/${uuid}`);
      if (!response.ok) {
        if (response.status === 404) throw new Error('Document non trouvé');
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
        ) : error ? (
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
              Nous n'avons trouvé aucun document authentique correspondant à ce code dans notre base de données.
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
              <div className="bg-green-50 p-6 rounded-full border border-green-100">
                <CheckCircle2 className="h-16 w-16 text-green-600" />
              </div>
            </div>
            
            <div className="space-y-2">
              <h1 className="text-2xl font-black text-slate-900 uppercase tracking-tighter">Authenticité Confirmée</h1>
              <p className="text-green-600 font-bold text-lg uppercase tracking-wide">
                {data.docType.toUpperCase()} VALIDÉ
              </p>
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
                  <p className="text-2xl font-black text-blue-900">{formatFCFA(data.montant)}</p>
                </div>
              </div>
            </div>

            <div className="bg-blue-50/50 p-4 rounded-lg border border-blue-100">
              <p className="text-[11px] text-blue-800 leading-relaxed font-medium">
                Ceci est une confirmation officielle du système ERP EDITIONS FABS-CI. 
                Ce document a été certifié et enregistré dans notre registre comptable.
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