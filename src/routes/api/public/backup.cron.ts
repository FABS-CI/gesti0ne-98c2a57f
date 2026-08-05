import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/api/public/backup/cron')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        // Sécurité : On peut vérifier un header secret si configuré, 
        // ou se fier à l'URL stable du projet.
        
        const { orchestrateBackup } = await import('@/lib/backup-orchestrator.server');
        
        try {
          // On utilise un utilisateur système (id 0000...0000 ou null si policies le permettent)
          // Ici on utilise supabaseAdmin à l'intérieur de l'orchestrateur.
          const result = await orchestrateBackup({
            trigger: "planifie",
            author: "system_cron",
            userId: "00000000-0000-0000-0000-000000000000" // ID fictif pour le cron
          });
          
          return new Response(JSON.stringify({ success: true, ...result }), {
            headers: { 'Content-Type': 'application/json' }
          });
        } catch (error) {
          return new Response(JSON.stringify({ success: false, error: (error as Error).message }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          });
        }
      }
    }
  }
})
