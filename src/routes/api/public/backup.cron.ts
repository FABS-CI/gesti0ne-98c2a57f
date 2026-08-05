import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/api/public/backup/cron')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        // Sécurité : Vérification d'un secret partagé pour éviter les appels malveillants
        const secret = request.headers.get('X-Backup-Secret');
        const expectedSecret = process.env.BACKUP_CRON_SECRET || 'fabs-ci-system-backup-secret-2026';
        
        if (secret !== expectedSecret) {
          return new Response('Unauthorized', { status: 401 });
        }
        
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
