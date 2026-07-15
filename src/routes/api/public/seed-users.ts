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

const SEED_TOKEN = 'k7Xq2vN8pR4tW9zL3mB6yH1jF5cE0aDs'

export const Route = createFileRoute('/api/public/seed-users')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const url = new URL(request.url)
        if (url.searchParams.get('token') !== SEED_TOKEN) {
          return new Response('Unauthorized', { status: 401 })
        }
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
