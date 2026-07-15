import { Button } from "@/components/ui/button";

/**
 * Pagination minimaliste partagée pour les grosses listes.
 * Contrôle serveur (page/pageSize). Le composant ne rend rien si total ≤ pageSize.
 */
export function TablePagination({
  page,
  pageSize,
  total,
  onPageChange,
}: {
  page: number;
  pageSize: number;
  total: number;
  onPageChange: (p: number) => void;
}) {
  if (total <= pageSize) return null;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  return (
    <div className="flex items-center justify-end gap-2 pt-2">
      <span className="text-sm text-muted-foreground">
        Page {page} / {totalPages} · {total} éléments
      </span>
      <Button
        variant="outline"
        size="sm"
        disabled={page <= 1}
        onClick={() => onPageChange(page - 1)}
      >
        Préc.
      </Button>
      <Button
        variant="outline"
        size="sm"
        disabled={page >= totalPages}
        onClick={() => onPageChange(page + 1)}
      >
        Suiv.
      </Button>
    </div>
  );
}
