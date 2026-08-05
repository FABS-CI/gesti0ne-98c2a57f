
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
            { name: 'factures', idCol: 'facture_id', type: 'Facture', dateCol: 'date_facture', montantCol: 'montant_total', refCol: 'reference' },
            { name: 'proformas', idCol: 'proforma_id', type: 'Proforma', dateCol: 'date_proforma', montantCol: 'montant_ttc', refCol: 'reference' },
            { name: 'commandes', idCol: 'commande_id', type: 'Commande', dateCol: 'date_commande', montantCol: 'montant_total', refCol: 'reference' },
            { name: 'bons_livraison', idCol: 'bl_id', type: 'Bon de Livraison', dateCol: 'date_bl', montantCol: 'montant_ttc', refCol: 'reference' }
          ];

          const results = await Promise.all(
            tables.map(async (table) => {
              // On essaie d'abord par UUID si c'est un UUID valide, sinon seulement par référence
              const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid);
              
              let query = supabaseAdmin
                .from(table.name as any)
                .select('*');
                
              if (isUuid) {
                query = query.or(`${table.idCol}.eq.${uuid},${table.refCol}.ilike.${uuid}`);
              } else {
                query = query.ilike(table.refCol, uuid);
              }

              const { data, error } = await query.maybeSingle();
              
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
          const typedFound = found as any;
          const publicData = {
            docType: typedFound.docType,
            reference: typedFound.reference,
            date: typedFound[typedFound.dateCol],
            client_nom: typedFound.client_nom,
            montant: typedFound[typedFound.montantCol] || typedFound.montant_ttc || typedFound.montant_total || typedFound.montant
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
