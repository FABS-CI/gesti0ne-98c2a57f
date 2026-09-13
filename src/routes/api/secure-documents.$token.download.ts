import { createFileRoute } from '@tanstack/react-router'

/** Jeton public : aléa base64url, jamais une référence métier ni un id interne. */
const TOKEN_RE = /^[A-Za-z0-9_-]{20,100}$/

const DOC_TYPE_LABEL: Record<string, string> = {
  FACTURE: 'FACTURE',
  PROFORMA: 'PROFORMA',
  COMMANDE: 'BON_DE_COMMANDE',
  BL: 'BON_DE_LIVRAISON',
}

export const Route = createFileRoute('/api/secure-documents/$token/download')({
  server: {
    handlers: {
      // Seul GET est autorisé sur cette route (Prompt 8 : rejet des autres méthodes).
      GET: async ({ params, request }) => {
        const { token } = params as { token: string }

        const ip =
          request.headers.get('cf-connecting-ip') ??
          request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
          null
        const userAgent = request.headers.get('user-agent')

        const {
          verifyTokenForDownload,
          loadFullDocumentForDownload,
          logVerification,
          isDownloadRateLimited,
          sha256Hex,
        } = await import('@/lib/certification/certification.server')

        // Réponse générique en cas d'échec : jamais de détail exploitable.
        const deny = (status: number, result: string) => {
          void logVerification({
            reference: `token:${sha256Hex(token).slice(0, 16)}`,
            result,
            ip,
            userAgent,
          })
          return Response.json(
            { error: 'Téléchargement non autorisé' },
            { status, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } },
          )
        }

        if (!TOKEN_RE.test(token)) return deny(400, 'DOWNLOAD_INVALID_TOKEN_FORMAT')

        if (await isDownloadRateLimited(ip, token)) return deny(429, 'DOWNLOAD_RATE_LIMITED')

        try {
          // Revalidation complète : jamais de résultat mis en cache côté client entre
          // la page de vérification et le téléchargement (Prompt 4).
          const result = await verifyTokenForDownload(token)

          if (result.status !== 'AUTHENTIC') {
            return deny(403, `DOWNLOAD_DENIED_${result.status}`)
          }
          if (!result.docType || !result.docId) {
            return deny(500, 'DOWNLOAD_DENIED_NO_DOCUMENT')
          }
          const document = (result as any).document
          const docType = result.docType
          const docId = result.docId

          const fullData = await loadFullDocumentForDownload(docType, docId, document)

          const { generateFacturePDF, generateProformaPDF, generateBonCommandePDF, generateBonLivraisonPDF, fileNameFor } =
            await import('@/lib/pdf/fabsTemplates')

          let blob: Blob
          switch (docType) {
            case 'FACTURE':
              blob = await generateFacturePDF(fullData as any)
              break
            case 'PROFORMA':
              blob = await generateProformaPDF(fullData as any)
              break
            case 'COMMANDE':
              blob = await generateBonCommandePDF(fullData as any)
              break
            case 'BL':
              blob = await generateBonLivraisonPDF(fullData as any)
              break
            default:
              return deny(500, 'DOWNLOAD_DENIED_UNSUPPORTED_TYPE')
          }

          const bytes = await blob.arrayBuffer()

          // Nom de fichier généré côté serveur uniquement (jamais depuis une entrée utilisateur).
          const filename = fileNameFor(document.reference, document.client_nom)
          const safeFilename = filename.replace(/[^A-Za-z0-9._-]/g, '_')

          void logVerification({
            certificationId: (result as any).certificationId ?? null,
            reference: `token:${sha256Hex(token).slice(0, 16)}`,
            result: `DOWNLOAD_SUCCESS_${DOC_TYPE_LABEL[docType] ?? docType}`,
            ip,
            userAgent,
          })

          return new Response(bytes, {
            status: 200,
            headers: {
              'Content-Type': 'application/pdf',
              'Content-Disposition': `attachment; filename="${safeFilename}"`,
              'Cache-Control': 'no-store',
              'X-Content-Type-Options': 'nosniff',
            },
          })
        } catch (error) {
          console.error('[secure-documents] erreur de téléchargement', error)
          return deny(503, 'DOWNLOAD_ERROR')
        }
      },
    },
  },
})
