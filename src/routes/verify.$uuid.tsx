
import { createFileRoute } from '@tanstack/react-router';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { CheckCircle2, XCircle, Loader2, FileText, Calendar, User } from 'lucide-react';
import { formatFCFA } from '@/lib/format';
import { Button } from '@/components/ui/button';

export const Route = createFileRoute('/verify/$uuid')({
  component: VerificationPage,
});

function VerificationPage() {
  const { uuid } = Route.useParams();

  const { data, isLoading, error } = useQuery({
    queryKey: ['verify-doc', uuid],
    queryFn: async () => {
      // Rechercher dans factures, proformas, commandes ou bons_livraison
      const tables = [
        { name: 'factures', idCol: 'facture_id', type: 'Facture' },
        { name: 'proformas', idCol: 'proforma_id', type: 'Proforma' },
        { name: 'commandes', idCol: 'commande_id', type: 'Commande' },
        { name: 'bons_livraison', idCol: 'bl_id', type: 'Bon de Livraison' }
      ];

      for (const table of tables) {
        const { data, error } = await supabase
          .from(table.name as any)
          .select('*')
          .eq(table.idCol, uuid)
          .maybeSingle();
        
        if (data) return { ...data, docType: table.type };
      }
      
      throw new Error('Document non trouvé');
    }
  });

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-8 text-center space-y-6">
        <div className="flex justify-center">
          <img src="/fabs-logo.png" alt="FABS-CI" className="h-16" />
        </div>

        {isLoading ? (
          <div className="flex flex-col items-center space-y-4">
            <Loader2 className="h-12 w-12 text-blue-600 animate-spin" />
            <p className="text-slate-500 font-medium">Vérification du document en cours...</p>
          </div>
        ) : error ? (
          <div className="space-y-4">
            <div className="flex justify-center">
              <div className="bg-red-100 p-4 rounded-full">
                <XCircle className="h-12 w-12 text-red-600" />
              </div>
            </div>
            <h1 className="text-2xl font-bold text-slate-900">Document Invalide</h1>
            <p className="text-slate-600">
              Nous n'avons trouvé aucun document correspondant à ce code de vérification.
            </p>
            <Button variant="outline" onClick={() => window.location.href = 'https://editionsfabs.ci'}>
              Retour au site
            </Button>
          </div>
        ) : (
          <div className="space-y-6">
            <div className="flex justify-center">
              <div className="bg-green-100 p-4 rounded-full">
                <CheckCircle2 className="h-12 w-12 text-green-600" />
              </div>
            </div>
            
            <div className="space-y-2">
              <h1 className="text-2xl font-bold text-slate-900">Authenticité Confirmée</h1>
              <p className="text-green-600 font-semibold text-lg">{data.docType} Authentique</p>
            </div>

            <div className="bg-slate-50 rounded-xl p-6 text-left space-y-4 border border-slate-100">
              <div className="flex items-center gap-3">
                <FileText className="h-5 w-5 text-slate-400" />
                <div>
                  <p className="text-xs text-slate-400 uppercase font-bold tracking-wider">Référence</p>
                  <p className="font-mono text-slate-900 font-semibold">{data.reference}</p>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <Calendar className="h-5 w-5 text-slate-400" />
                <div>
                  <p className="text-xs text-slate-400 uppercase font-bold tracking-wider">Date d'émission</p>
                  <p className="text-slate-900 font-semibold">{new Date(data.date_facture || data.date_commande || data.date_bon).toLocaleDateString('fr-FR')}</p>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <User className="h-5 w-5 text-slate-400" />
                <div>
                  <p className="text-xs text-slate-400 uppercase font-bold tracking-wider">Client</p>
                  <p className="text-slate-900 font-semibold">{data.client_nom}</p>
                </div>
              </div>

              <div className="pt-4 border-t border-slate-200">
                <div className="flex justify-between items-center">
                  <p className="text-slate-500 font-medium">Montant Total</p>
                  <p className="text-xl font-bold text-blue-900">{formatFCFA(data.montant_total || data.montant_ttc || data.montant)}</p>
                </div>
              </div>
            </div>

            <p className="text-xs text-slate-400 leading-relaxed">
              Ce document a été généré électroniquement par le système de gestion ERP FABS-CI. 
              Pour toute question relative à ce document, veuillez contacter notre service comptabilité.
            </p>
          </div>
        )}
      </div>
      
      <p className="mt-8 text-slate-400 text-sm">
        © {new Date().getFullYear()} EDITIONS FABS-CI. Tous droits réservés.
      </p>
    </div>
  );
}
