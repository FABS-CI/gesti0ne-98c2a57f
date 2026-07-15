import { createFileRoute } from '@tanstack/react-router'

const USERS = [
  { email: 'pissken@editionsfabsci.com', password: 'Admin@2025' },
  { email: 'ali.mamin@editionsfabsci.com', password: 'Fabs2026!' },
  { email: 'natachakoffi@editionsfabsci.com', password: 'Fabs2026!' },
  { email: 'detymichel@editionsfabsci.com', password: 'Fabs2026!' },
  { email: 'niangoran.georgie@editionsfabsci.com', password: 'Fabs2026!' },
  { email: 'joachin@editionsfabsci.com', password: 'Fabs2026!' },
  { email: 'dadjelarissa@editionsfabsci.com', password: 'Fabs2026!' },
  { email: 'amenan@editionsfabsci.com', password: 'Fabs2026!' },
  { email: 'yakeben@editionsfabsci.com', password: 'Fabs2026!' },
]

export const Route = createFileRoute('/api/public/seed-users')({
  server: {
    handlers: {
      GET: async () => {
        const { supabaseAdmin } = await import('@/integrations/supabase/client.server')
        const results: Array<{ email: string; status: string; error?: string }> = []
        for (const u of USERS) {
          const { error } = await supabaseAdmin.auth.admin.createUser({
            email: u.email,
            password: u.password,
            email_confirm: true,
          })
          results.push({
            email: u.email,
            status: error ? 'error' : 'created',
            ...(error ? { error: error.message } : {}),
          })
        }
        return new Response(JSON.stringify({ results }, null, 2), {
          headers: { 'content-type': 'application/json' },
        })
      },
    },
  },
})
