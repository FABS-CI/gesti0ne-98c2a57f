import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/api/public/verify-doc/$uuid')({
  server: {
    handlers: {
      GET: async ({ params, request }) => {
        const { uuid } = params as { uuid: string }

        try {
          const {
            verifyByReference,
            verifyByToken,
            logVerification,
            isRateLimited,
          } = await import('@/lib/certification/certification.server')

          const url = new URL(request.url)
          const token = url.searchParams.get('t')
          const ip =
            request.headers.get('cf-connecting-ip') ??
            request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
            null
          const userAgent = request.headers.get('user-agent')

          if (await isRateLimited(ip)) {
            return Response.json(
              { status: 'RATE_LIMITED', error: 'Trop de vérifications, réessayez plus tard.' },
              { status: 429, headers: { 'Cache-Control': 'no-store' } },
            )
          }

          const result = token ? await verifyByToken(token) : await verifyByReference(uuid)

          await logVerification({
            reference: token ? null : uuid,
            result: result.status,
            ip,
            userAgent,
          })

          if (result.status === 'INVALID') {
            return Response.json(
              { status: 'INVALID', error: 'Document non trouvé' },
              { status: 404, headers: { 'Cache-Control': 'no-store' } },
            )
          }

          const doc = result.document
          return Response.json(
            {
              status: result.status,
              reason: 'reason' in result ? result.reason ?? null : null,
              docType: doc.docType,
              reference: doc.reference,
              date: doc.date,
              client_nom: doc.client_nom,
              representant_nom: doc.representant_nom ?? null,
              montant: doc.montant,
              statut_document: doc.statut_document ?? null,
              certified_at: doc.certified_at ?? null,
              canonical_hash: doc.canonical_hash ?? null,
              signature_algorithm: doc.signature_algorithm ?? null,
            },
            { status: 200, headers: { 'Cache-Control': 'no-store' } },
          )
        } catch (error) {
          console.error('Verification handler error:', error)
          return Response.json({ error: 'Erreur serveur' }, { status: 500 })
        }
      },
    },
  },
})
