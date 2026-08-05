
export function buildQrUrl(uuid: string): string {
  // En production, utiliser le domaine réel.
  // En développement, utiliser le domaine de preview.
  const domain = typeof window !== 'undefined' ? window.location.origin : 'https://erp.editionsfabs.ci';
  return `${domain}/verify/${uuid}`;
}
