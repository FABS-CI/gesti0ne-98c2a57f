
import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'

export const Route = createFileRoute('/api/public/verify-doc/$uuid')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        const { uuid } = params as { uuid: string };
        
        try {
          const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

          // Stratégie de recherche parallèle pour la rapidité
          const tables = [
            { name: 'factures', idCol: 'facture_id', type: 'Facture', dateCol: 'date_facture', montantCol: 'montant_total' },
            { name: 'proformas', idCol: 'proforma_id', type: 'Proforma', dateCol: 'date_proforma', montantCol: 'montant_ttc' },
            { name: 'commandes', idCol: 'commande_id', type: 'Commande', dateCol: 'date_commande', montantCol: 'montant_total' },
            { name: 'bons_livraison', idCol: 'bl_id', type: 'Bon de Livraison', dateCol: 'date_bl', montantCol: 'montant_ttc' }
          ];

          const results = await Promise.all(
            tables.map(async (table) => {
              const { data, error } = await supabaseAdmin
                .from(table.name as any)
                .select('*')
                .eq(table.idCol, uuid)
                .maybeSingle();
              
              if (error) {
                console.error(`Error querying ${table.name}:`, error);
                return null;
              }
              
              return data ? { ...Object(data), docType: table.type, dateCol: table.dateCol, montantCol: table.montantCol } : null;
            })
          );

          const found = results.find(r => r !== null);
          
          if (!found) {
            return new Response(JSON.stringify({ error: 'Document non trouvé' }), {
              status: 404,
              headers: { 'Content-Type': 'application/json' }
            });
          }

          // Nettoyer l'objet de retour pour n'inclure que le strict nécessaire (public)
          const publicData = {
            docType: found.docType,
            reference: found.reference,
            date: found[found.dateCol],
            client_nom: found.client_nom,
            montant: found[found.montantCol] || found.montant_ttc || found.montant_total || found.montant
          };

          return new Response(JSON.stringify(publicData), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
          });
        } catch (error) {
          console.error('Verification handler error:', error);
          return new Response(JSON.stringify({ error: 'Erreur serveur' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          });
        }
      }
    }
  }
})
